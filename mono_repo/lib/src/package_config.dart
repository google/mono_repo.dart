// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checked_yaml/checked_yaml.dart';
import 'package:io/ansi.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

import 'package_flavor.dart';
import 'raw_config.dart';
import 'task_type.dart';
import 'utilities.dart';
import 'yaml.dart';

part 'package_config.g.dart';

const monoPkgFileName = 'mono_pkg.yaml';

class PackageConfig {
  final String relativePath;
  final Pubspec pubspec;

  final List<String> oses;
  final List<String>? sdks;
  final List<String> stageNames;
  final List<CIJob> jobs;
  final List<String> cacheDirectories;
  final bool dartSdkConfigUsed;
  final bool osConfigUsed;

  PackageConfig(
    this.relativePath,
    this.pubspec,
    this.oses,
    this.sdks,
    this.stageNames,
    this.jobs,
    this.cacheDirectories,
    this.dartSdkConfigUsed,
    this.osConfigUsed,
  ) : assert(() {
          if (sdks == null) return true;
          sortNormalizeVerifySdksList(
            pubspec.flavor,
            sdks,
            AssertionError.new,
          );
          return true;
        }());

  factory PackageConfig.parse(
    String relativePath,
    Pubspec pubspec,
    Map monoPkgYaml,
  ) =>
      createWithCheck(
        () => PackageConfig._parse(relativePath, pubspec, monoPkgYaml),
      );

  factory PackageConfig._parse(
    String relativePath,
    Pubspec pubspec,
    Map monoPkgYaml,
  ) {
    if (monoPkgYaml.isEmpty) {
      // It's valid to have an empty `mono_pkg.yaml` file – it just results in
      // an empty config WRT travis.
      return PackageConfig(
        relativePath,
        pubspec,
        [],
        [],
        [],
        [],
        [],
        false,
        false,
      );
    }

    final flavor = pubspec.flavor;

    final rawConfig = RawConfig.fromYaml(flavor, monoPkgYaml);

    // FYI: 'test' is default if there are no tasks defined
    final jobs = <CIJob>[];

    var sdkConfigUsed = false;
    var osConfigUsed = false;

    final stageNames = rawConfig.stages.map((stage) {
      final stageYaml = stage.items;
      for (var job in stageYaml) {
        var jobSdks = rawConfig.sdks;
        if (job is Map && job.containsKey('sdk')) {
          final jobValue = job['sdk'];

          jobSdks = (jobValue is List)
              ? jobSdks = List.from(jobValue)
              : [jobValue as String];

          sortNormalizeVerifySdksList(
            flavor,
            jobSdks,
            (m) => CheckedFromJsonException(job, 'sdk', 'RawConfig', m),
          );
        } else if (jobSdks == null || jobSdks.isEmpty) {
          if (monoPkgYaml.containsKey('sdk')) {
            throw CheckedFromJsonException(
              monoPkgYaml,
              'sdk',
              'RawConfig',
              'The value for "sdk" must be an array with at least '
                  'one value.',
            );
          }

          if (job is! Map) {
            throw ParsedYamlException(
              'Each item within a stage must be a map.',
              job is YamlNode ? job : stageYaml as YamlNode,
            );
          }

          if (job.containsKey('dart')) {
            throw CheckedFromJsonException(
              job as YamlMap,
              'dart',
              'RawConfig',
              '"dart" is no longer supported. Use "sdk" instead.',
            );
          }

          throw ParsedYamlException(
            'An "sdk" key is required.',
            job as YamlMap,
          );
        } else {
          sdkConfigUsed = true;
        }

        var jobOses = rawConfig.oses;
        if (job is Map && job.containsKey('os')) {
          final jobValue = job['os'];
          if (jobValue is List) {
            jobOses = jobValue.cast<String>();
          } else {
            jobOses = [jobValue as String];
          }
        } else {
          osConfigUsed = true;
        }

        for (var sdk in jobSdks) {
          for (var os in jobOses) {
            jobs.add(
              CIJob.parse(
                os,
                relativePath,
                sdk,
                stage.name,
                job as Object,
                flavor: flavor,
              ),
            );
          }
        }
      }
      return stage.name;
    }).toList();

    return PackageConfig(
      relativePath,
      pubspec,
      rawConfig.oses,
      rawConfig.sdks,
      stageNames,
      jobs,
      rawConfig.cache?.directories ?? const [],
      sdkConfigUsed,
      osConfigUsed,
    );
  }
}

abstract class HasStageName {
  String get stageName;
}

@JsonSerializable(
  explicitToJson: true,
  createFactory: false,
  ignoreUnannotated: true,
)
class CIJob implements HasStageName {
  @JsonKey(includeIfNull: false)
  final String? description;

  @JsonKey()
  final String os;

  /// Relative path to the directory containing the source package from the root
  /// of the repository.
  @JsonKey()
  final String package;

  @JsonKey()
  final String sdk;

  @override
  @JsonKey()
  final String stageName;

  @JsonKey()
  final List<Task> tasks;

  @JsonKey()
  final PackageFlavor flavor;

  Iterable<String> get _taskCommandsTickQuoted =>
      tasks.map((t) => '`${t.command}`');

  /// The description of the job in the CI environment.
  String get name => description ?? _taskCommandsTickQuoted.join(', ');

  /// Values used to group jobs together.
  List<String> get groupByKeys => [os, stageName, sdk];

  /// Values used to sort jobs within a group.
  String get sortBits => [
        ...groupByKeys,
        package,
        name,
      ].join(':::');

  CIJob(
    this.os,
    this.package,
    this.sdk,
    this.stageName,
    this.tasks, {
    this.description,
    required this.flavor,
  }) : assert(
          errorForSdkConfig(flavor, sdk) == null,
          'Should have caught bad sdk value `$sdk` before here!',
        );

  factory CIJob.parse(
    String os,
    String package,
    String sdk,
    String stageName,
    Object yaml, {
    required PackageFlavor flavor,
  }) {
    String? description;
    Object withoutDescription;
    if (yaml is Map && yaml.containsKey('description')) {
      withoutDescription = transferYamlMap(yaml as YamlMap);
      description = (withoutDescription as Map).remove('description') as String;
    } else {
      withoutDescription = yaml;
    }
    final tasks = Task.parseTaskOrGroup(flavor, withoutDescription);
    return CIJob(
      os,
      package,
      sdk,
      stageName,
      tasks,
      description: description,
      flavor: flavor,
    );
  }

  /// If [sdk] is a valid [Version], return it. Otherwise, `null`.
  @JsonKey(ignore: true)
  Version? get explicitSdkVersion {
    try {
      return Version.parse(sdk);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> toJson() => _$CIJobToJson(this);
}

@JsonSerializable(
  createFactory: false,
  ignoreUnannotated: true,
  includeIfNull: false,
)
class Task {
  @JsonKey()
  final PackageFlavor flavor;

  @JsonKey()
  final TaskType type;

  @JsonKey()
  final String? args;

  final String command;

  Task(this.flavor, this.type, {this.args})
      : command = type.commandValue(flavor, args).join(' ');

  /// Parses an individual item under `stages`, which might be a `group` or an
  /// individual task.
  static List<Task> parseTaskOrGroup(PackageFlavor flavor, Object yamlValue) {
    if (yamlValue is Map) {
      final group = yamlValue['group'];
      if (group != null) {
        if (group is List) {
          return group
              .map((taskYaml) => Task.parse(flavor, taskYaml as Object))
              .toList();
        } else {
          throw CheckedFromJsonException(
            yamlValue,
            'group',
            'group',
            'expected a list of tasks',
          );
        }
      }
    }
    return [Task.parse(flavor, yamlValue)];
  }

  factory Task.parse(PackageFlavor flavor, Object yamlValue) {
    if (yamlValue is String) {
      if (yamlValue == TaskType.command.name) {
        throw ArgumentError.value(yamlValue, 'command', 'requires a value');
      }
      return Task(flavor, _taskTypeForName(yamlValue));
    }

    if (yamlValue is Map) {
      final taskNames = yamlValue.keys
          .where(TaskType.allowedTaskNames.contains)
          .cast<String>()
          .toList();
      if (taskNames.isEmpty) {
        String? key;
        if (yamlValue.isNotEmpty) {
          key = yamlValue.keys.first as String;
        }
        throw CheckedFromJsonException(
          yamlValue,
          key,
          'Task',
          'Must have one key of ${TaskType.prettyTaskList}.',
          badKey: true,
        );
      }
      if (taskNames.length > 1) {
        throw CheckedFromJsonException(
          yamlValue,
          taskNames.skip(1).first,
          'Task',
          'Must have one and only one key of ${TaskType.prettyTaskList}.',
          badKey: true,
        );
      }

      final taskName = taskNames.single;
      final taskType = _taskTypeForName(taskName);

      String? args;
      switch (taskType) {
        case TaskType.command:
          final taskValue = yamlValue[taskType.name];
          if (taskValue is String) {
            args = taskValue;
          } else if (taskValue is List &&
              taskValue.every((element) => element is String)) {
            args = taskValue.join(' && ');
          } else {
            throw CheckedFromJsonException(
              yamlValue,
              taskType.name,
              'TaskType',
              'Only supports a string or array of strings',
            );
          }
          break;
        default:
          // NOTE: using `taskName.single` in case it's a deprecated name
          args = yamlValue[taskName] as String?;
      }

      final extraConfig = Set<String>.from(yamlValue.keys)
        ..removeAll([taskName, 'os', 'sdk']);

      // TODO(kevmoo): at some point, support custom configuration here
      if (extraConfig.isNotEmpty) {
        throw CheckedFromJsonException(
          yamlValue,
          extraConfig.first,
          'Task',
          'Extra config options are not currently supported.',
          badKey: true,
        );
      }
      try {
        return Task(flavor, taskType, args: args);
      } on InvalidTaskConfigException catch (e) {
        throw CheckedFromJsonException(
          yamlValue,
          taskName,
          'Task',
          e.message,
        );
      }
    }

    if (yamlValue is YamlNode) {
      throw ParsedYamlException('Must be a map or a string.', yamlValue);
    }

    throw ArgumentError('huh? $yamlValue ${yamlValue.runtimeType}');
  }

  Map<String, dynamic> toJson() => _$TaskToJson(this);

  /// Stores the job names we've already warned about. Only warn once!
  static final _warnedNames = <TaskType>{};

  static TaskType _taskTypeForName(String input) {
    final taskName = TaskType.taskFromName(input);
    if (taskName.name != input && _warnedNames.add(taskName)) {
      print(
        yellow.wrap(
          '"$input" is deprecated. Use "$taskName" instead to define tasks in '
          '`$monoPkgFileName`.',
        ),
      );
    }
    return taskName;
  }
}
