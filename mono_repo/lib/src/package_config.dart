// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checked_yaml/checked_yaml.dart';
import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

import 'raw_config.dart';
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
          sortNormalizeVerifySdksList(sdks, (m) => AssertionError(m));
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
    final rawConfig = RawConfig.fromJson(monoPkgYaml);

    // FYI: 'test' is default if there are no tasks defined
    final jobs = <CIJob>[];

    var sdkConfigUsed = false;
    var osConfigUsed = false;

    final stageNames = rawConfig.stages.map((stage) {
      final stageYaml = stage.items;
      for (var job in stageYaml) {
        var jobSdks = rawConfig.sdks;
        if (job is Map && job.containsKey('dart')) {
          final jobValue = job['dart'];

          jobSdks = (jobValue is List)
              ? jobSdks = List.from(jobValue)
              : [jobValue as String];

          sortNormalizeVerifySdksList(
            jobSdks,
            (m) => CheckedFromJsonException(job, 'dart', 'RawConfig', m),
          );
        } else if (jobSdks == null || jobSdks.isEmpty) {
          if (monoPkgYaml.containsKey('dart')) {
            throw CheckedFromJsonException(
              monoPkgYaml,
              'dart',
              'RawConfig',
              'The value for "dart" must be an array with at least one value.',
            );
          }

          if (job is! Map) {
            throw ParsedYamlException(
              'Each item within a stage must be a map.',
              job is YamlNode ? job : stageYaml as YamlNode,
            );
          }

          throw ParsedYamlException(
            'A "dart" key is required.',
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
              CIJob.parse(os, relativePath, sdk, stage.name, job as Object),
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

  bool get hasFlutterDependency {
    if (pubspec.environment!.containsKey('flutter')) {
      return true;
    }
    return pubspec.dependencies.values.any(
      (dependency) =>
          dependency is SdkDependency && dependency.sdk == 'flutter',
    );
  }
}

abstract class HasStageName {
  String get stageName;
}

@JsonSerializable(explicitToJson: true)
class CIJob implements HasStageName {
  @JsonKey(includeIfNull: false)
  final String? description;

  final String os;

  /// Relative path to the directory containing the source package from the root
  /// of the repository.
  final String package;

  final String sdk;

  @override
  final String stageName;

  final List<Task> tasks;

  Iterable<String> get _taskCommandsTickQuoted =>
      tasks.map((t) => '`${t.command}`');

  /// The description of the job in the CI environment.
  String get name => description ?? _taskCommandsTickQuoted.join(', ');

  /// Same as [sdk] except it handles Travis-specific naming for the edge SDK.
  String get travisSdk => sdk == githubSetupMainSdk ? travisEdgeSdk : sdk;

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
  }) : assert(
          errorForSdkConfig(sdk) == null,
          'Should have caught bad sdk value `$sdk` before here!',
        );

  factory CIJob.fromJson(Map<String, dynamic> json) => _$CIJobFromJson(json);

  factory CIJob.parse(
    String os,
    String package,
    String sdk,
    String stageName,
    Object yaml,
  ) {
    String? description;
    Object withoutDescription;
    if (yaml is Map && yaml.containsKey('description')) {
      withoutDescription = transferYamlMap(yaml as YamlMap);
      description = (withoutDescription as Map).remove('description') as String;
    } else {
      withoutDescription = yaml;
    }
    final tasks = Task.parseTaskOrGroup(withoutDescription);
    return CIJob(
      os,
      package,
      sdk,
      stageName,
      tasks,
      description: description,
    );
  }

  /// If [sdk] is a valid [Version], return it. Otherwise, `null`.
  Version? get explicitSdkVersion {
    try {
      return Version.parse(sdk);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> toJson() => _$CIJobToJson(this);

  @override
  String toString() => 'CIJob: ${toJson()}';

  @override
  bool operator ==(Object other) =>
      other is CIJob && _equality.equals(_items, other._items);

  @override
  int get hashCode => _equality.hash(_items);

  List get _items => [description, package, sdk, stageName, tasks];
}

@JsonSerializable(includeIfNull: false)
class Task {
  static const _tasks = ['dartfmt', 'dartanalyzer', 'test', 'command'];
  static final _prettyTaskList = _tasks.map((t) => '`$t`').join(', ');

  final String name;

  final String? args;

  final String command;

  Task(this.name, {this.args}) : command = _commandValue(name, args);

  /// Parses an individual item under `stages`, which might be a `group` or an
  /// individual task.
  static List<Task> parseTaskOrGroup(Object yamlValue) {
    if (yamlValue is Map) {
      final group = yamlValue['group'];
      if (group != null) {
        if (group is List) {
          return group
              .map((taskYaml) => Task.parse(taskYaml as Object))
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
    return [Task.parse(yamlValue)];
  }

  factory Task.parse(Object yamlValue) {
    if (yamlValue is String) {
      if (yamlValue == 'command') {
        throw ArgumentError.value(yamlValue, 'command', 'requires a value');
      }
      return Task(yamlValue);
    }

    if (yamlValue is Map) {
      final taskNames =
          yamlValue.keys.where(_tasks.contains).cast<String>().toList();
      if (taskNames.isEmpty) {
        String? key;
        if (yamlValue.isNotEmpty) {
          key = yamlValue.keys.first as String;
        }
        throw CheckedFromJsonException(
          yamlValue,
          key,
          'Task',
          'Must have one key of $_prettyTaskList.',
          badKey: true,
        );
      }
      if (taskNames.length > 1) {
        throw CheckedFromJsonException(
          yamlValue,
          taskNames.skip(1).first,
          'Task',
          'Must have one and only one key of $_prettyTaskList.',
          badKey: true,
        );
      }
      final taskName = taskNames.single;
      String? args;
      switch (taskName) {
        case 'command':
          final taskValue = yamlValue[taskName];
          if (taskValue is String) {
            args = taskValue;
          } else if (taskValue is List &&
              taskValue.every((element) => element is String)) {
            args = taskValue.join(' && ');
          } else {
            throw CheckedFromJsonException(
              yamlValue,
              taskName,
              'command',
              'Only supports a string or array of strings',
            );
          }
          break;
        default:
          args = yamlValue[taskName] as String?;
      }

      final extraConfig = Set<String>.from(yamlValue.keys)
        ..removeAll([taskName, 'dart', 'os']);

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
      return Task(taskName, args: args);
    }

    if (yamlValue is YamlNode) {
      throw ParsedYamlException('Must be a map or a string.', yamlValue);
    }

    throw ArgumentError('huh? $yamlValue ${yamlValue.runtimeType}');
  }

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  Map<String, dynamic> toJson() => _$TaskToJson(this);

  static String _commandValue(String name, String? args) {
    switch (name) {
      case 'dartfmt':
        if (args == null || args == 'sdk') {
          return 'dartfmt -n --set-exit-if-changed .';
        }
        return 'dartfmt $args';
      case 'dartanalyzer':
        if (args == null) {
          return 'dartanalyzer .';
        }
        return 'dartanalyzer $args';

      case 'test':
        var value = 'pub run test';
        if (args != null) {
          value = '$value $args';
        }
        return value;
      case 'command':
        return args!;
      default:
        throw UnsupportedError('Cannot generate the command for `$name`.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Task && _equality.equals(_items, other._items);

  @override
  int get hashCode => _equality.hash(_items);

  List get _items => [name, args];
}

const _equality = DeepCollectionEquality();
