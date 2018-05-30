// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

import 'raw_config.dart';

part 'mono_config.g.dart';

final monoFileName = '.mono_repo.yml';
final travisFileName = '.travis.yml';
final travisShPath = './tool/travis.sh';

class MonoConfig {
  final List<String> sdks;

  final List<String> stageNames;

  final List<TravisJob> jobs;

  MonoConfig(this.sdks, this.stageNames, this.jobs);

  factory MonoConfig.parse(String package, Map monoYaml) {
    var rawConfig = new RawConfig.fromJson(monoYaml);

    // FYI: 'test' is default if there are no tasks defined
    var jobs = <TravisJob>[];

    var stageNames = rawConfig.stages.map((stage) {
      var stageYaml = stage.items;
      for (var job in stageYaml) {
        var jobSdks = rawConfig.sdks;
        if (job is Map && job.containsKey('dart')) {
          job = new Map<String, dynamic>.from(job as Map);
          jobSdks = (job.remove('dart') as List).cast<String>();
        }
        for (var sdk in jobSdks) {
          jobs.add(new TravisJob.parse(package, sdk, stage.name, job));
        }
      }
      return stage.name;
    }).toList();

    return new MonoConfig(rawConfig.sdks, stageNames, jobs);
  }
}

@JsonSerializable()
class TravisJob extends Object with _$TravisJobSerializerMixin {
  @override
  final String package;

  @override
  final String sdk;

  @override
  final String stageName;

  @override
  final List<Task> tasks;

  TravisJob(this.package, this.sdk, this.stageName, this.tasks);

  factory TravisJob.fromJson(Map<String, dynamic> json) =>
      _$TravisJobFromJson(json);

  factory TravisJob.parse(
          String package, String sdk, String stageName, Object yaml) =>
      new TravisJob(package, sdk, stageName, Task.parseTaskOrGroup(yaml));

  @override
  bool operator ==(Object other) =>
      other is TravisJob && _equality.equals(_items, other._items);

  @override
  int get hashCode => _equality.hash(_items);

  List get _items => [sdk, tasks];
}

@JsonSerializable(includeIfNull: false)
class Task extends Object with _$TaskSerializerMixin {
  static final _tasks = const ['dartfmt', 'dartanalyzer', 'test', 'command'];
  static final _prettyTaskList = _tasks.map((t) => '`$t`').join(', ');

  @override
  final String name;

  @override
  final String args;

  @override
  final Map<String, dynamic> config;

  Task(this.name, {this.args, this.config});

  /// Parses an individual item under `stages`, which might be a `group` or an
  /// individual task.
  static List<Task> parseTaskOrGroup(Object yamlValue) {
    if (yamlValue is Map) {
      var group = yamlValue['group'];
      if (group != null) {
        if (group is List) {
          return group.map((taskYaml) => new Task.parse(taskYaml)).toList();
        } else {
          throw new ArgumentError.value(
              group, 'group', 'expected a list of tasks');
        }
      }
    }
    return [new Task.parse(yamlValue)];
  }

  factory Task.parse(Object yamlValue) {
    if (yamlValue is String) {
      if (yamlValue == 'command') {
        throw new ArgumentError.value(yamlValue, 'command', 'requires a value');
      }
      return new Task(yamlValue);
    }

    if (yamlValue is Map) {
      var taskNames =
          yamlValue.keys.where(_tasks.contains).cast<String>().toList();
      if (taskNames.isEmpty) {
        String key;
        if (yamlValue.isNotEmpty) {
          key = yamlValue.keys.first as String;
        }
        throw new CheckedFromJsonException(
            yamlValue, key, 'Task', 'Must have one key of $_prettyTaskList.');
      }
      if (taskNames.length > 1) {
        throw new CheckedFromJsonException(yamlValue, taskNames.skip(1).first,
            'Task', 'Must have one and only one key of $_prettyTaskList.');
      }
      var taskName = taskNames.single;
      String args;
      switch (taskName) {
        case 'command':
          var taskValue = yamlValue[taskName];
          if (taskValue is String) {
            args = taskValue;
          } else if (taskValue is List<String>) {
            args = taskValue.join(';');
          } else {
            throw new ArgumentError.value(taskValue, 'command',
                'only supports a string or array of strings');
          }
          break;
        default:
          args = yamlValue[taskName] as String;
      }

      var config = new Map<String, dynamic>.from(yamlValue);
      config.remove(taskName);

      if (config.isEmpty) {
        config = null;
      }
      return new Task(taskName, args: args, config: config);
    }

    throw new ArgumentError('huh? $yamlValue ${yamlValue.runtimeType}');
  }

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

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
        throw new UnsupportedError('Cannot generate the command for `$name`.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Task && _equality.equals(_items, other._items);

  @override
  int get hashCode => _equality.hash(_items);

  List get _items => [name, args, config];
}

final _equality = const DeepCollectionEquality.unordered();
