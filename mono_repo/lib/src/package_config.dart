// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'raw_config.dart';

part 'package_config.g.dart';

final monoPkgFileName = 'mono_pkg.yaml';
final travisFileName = '.travis.yml';
final travisShPath = './tool/travis.sh';

class PackageConfig {
  final String relativePath;
  final Pubspec pubspec;

  final List<String> sdks;
  final List<String> stageNames;
  final List<TravisJob> jobs;
  final List<String> cacheDirectories;
  final bool dartSdkConfigUsed;

  PackageConfig(
    this.relativePath,
    this.pubspec,
    this.sdks,
    this.stageNames,
    this.jobs,
    this.cacheDirectories,
    this.dartSdkConfigUsed,
  );

  factory PackageConfig.parse(
      String relativePath, Pubspec pubspec, Map monoPkgYaml) {
    if (monoPkgYaml.isEmpty) {
      // It's valid to have an empty `mono_pkg.yaml` file – it just results in
      // an empty config WRT travis.
      return PackageConfig(relativePath, pubspec, [], [], [], [], false);
    }
    final rawConfig = RawConfig.fromJson(monoPkgYaml);

    // FYI: 'test' is default if there are no tasks defined
    final jobs = <TravisJob>[];

    var sdkConfigUsed = false;

    final stageNames = rawConfig.stages.map((stage) {
      final stageYaml = stage.items;
      for (var job in stageYaml) {
        var jobSdks = rawConfig.sdks;
        if (job is Map && job.containsKey('dart')) {
          job = Map<String, dynamic>.from(job as Map);
          final jobValue = job.remove('dart');
          if (jobValue is List) {
            jobSdks = jobValue.cast<String>();
          } else {
            jobSdks = [jobValue as String];
          }
        } else if (jobSdks == null || jobSdks.isEmpty) {
          if (monoPkgYaml.containsKey('dart')) {
            throw CheckedFromJsonException(
              monoPkgYaml,
              'dart',
              'RawConfig',
              '"dart" must be an array with at least one value.',
            );
          }

          throw CheckedFromJsonException(
            monoPkgYaml,
            'dart',
            'RawConfig',
            '"dart" is missing.',
          );
        } else {
          sdkConfigUsed = true;
        }
        for (var sdk in jobSdks) {
          jobs.add(TravisJob.parse(relativePath, sdk, stage.name, job));
        }
      }
      return stage.name;
    }).toList();

    return PackageConfig(relativePath, pubspec, rawConfig.sdks, stageNames,
        jobs, rawConfig.cache?.directories ?? const [], sdkConfigUsed);
  }
}

@JsonSerializable(explicitToJson: true)
class TravisJob {
  @JsonKey(includeIfNull: false)
  final String description;

  /// Relative path to the directory containing the source package from the root
  /// of the repository.
  final String package;

  final String sdk;

  final String stageName;

  final List<Task> tasks;

  Iterable<String> get _taskCommandsTickQuoted =>
      tasks.map((t) => '`${t.command}`');

  /// The description of the job to use for the job in the travis dashboard.
  String get name =>
      description ??
      (tasks.length > 1
          ? _taskCommandsTickQuoted.toList().toString()
          : _taskCommandsTickQuoted.first);

  TravisJob(this.package, this.sdk, this.stageName, this.tasks,
      {this.description});

  factory TravisJob.fromJson(Map<String, dynamic> json) =>
      _$TravisJobFromJson(json);

  factory TravisJob.parse(
      String package, String sdk, String stageName, Object yaml) {
    String description;
    dynamic withoutDescription;
    if (yaml is Map && yaml.containsKey('description')) {
      withoutDescription = Map.of(yaml);
      description = withoutDescription.remove('description') as String;
    } else {
      withoutDescription = yaml;
    }
    final tasks = Task.parseTaskOrGroup(withoutDescription);
    return TravisJob(package, sdk, stageName, tasks, description: description);
  }

  Map<String, dynamic> toJson() => _$TravisJobToJson(this);

  @override
  bool operator ==(Object other) =>
      other is TravisJob && _equality.equals(_items, other._items);

  @override
  int get hashCode => _equality.hash(_items);

  List get _items => [description, package, sdk, stageName, tasks];
}

@JsonSerializable(includeIfNull: false)
class Task {
  static final _tasks = const ['dartfmt', 'dartanalyzer', 'test', 'command'];
  static final _prettyTaskList = _tasks.map((t) => '`$t`').join(', ');

  final String name;

  final String args;

  Task(this.name, {this.args});

  /// Parses an individual item under `stages`, which might be a `group` or an
  /// individual task.
  static List<Task> parseTaskOrGroup(Object yamlValue) {
    if (yamlValue is Map) {
      final group = yamlValue['group'];
      if (group != null) {
        if (group is List) {
          return group.map((taskYaml) => Task.parse(taskYaml)).toList();
        } else {
          throw ArgumentError.value(group, 'group', 'expected a list of tasks');
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
        String key;
        if (yamlValue.isNotEmpty) {
          key = yamlValue.keys.first as String;
        }
        throw CheckedFromJsonException(
            yamlValue, key, 'Task', 'Must have one key of $_prettyTaskList.');
      }
      if (taskNames.length > 1) {
        throw CheckedFromJsonException(yamlValue, taskNames.skip(1).first,
            'Task', 'Must have one and only one key of $_prettyTaskList.');
      }
      final taskName = taskNames.single;
      String args;
      switch (taskName) {
        case 'command':
          final taskValue = yamlValue[taskName];
          if (taskValue is String) {
            args = taskValue;
          } else if (taskValue is List<String>) {
            args = taskValue.join(';');
          } else {
            throw ArgumentError.value(taskValue, 'command',
                'only supports a string or array of strings');
          }
          break;
        default:
          args = yamlValue[taskName] as String;
      }

      var config = Map<String, dynamic>.from(yamlValue)..remove(taskName);

      // TODO(kevmoo): at some point, support custom configuration here
      if (config.isNotEmpty) {
        throw CheckedFromJsonException(yamlValue, config.keys.first, 'Task',
            'Extra config options are not currently supported.');
      }
      return Task(taskName, args: args);
    }

    throw ArgumentError('huh? $yamlValue ${yamlValue.runtimeType}');
  }

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  Map<String, dynamic> toJson() => _$TaskToJson(this);

  String get command {
    switch (name) {
      case 'dartfmt':
        assert(args == null || args == 'sdk');
        return 'dartfmt -n --set-exit-if-changed .';
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
        return args;
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

final _equality = const DeepCollectionEquality();
