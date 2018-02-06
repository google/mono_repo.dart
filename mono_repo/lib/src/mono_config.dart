// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library mono_repo.travis_config;

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mono_config.g.dart';

final monoFileName = '.mono_repo.yml';
final travisFileName = '.travis.yml';
final travisShPath = './tool/travis.sh';

@JsonSerializable()
class MonoConfig extends Object with _$MonoConfigSerializerMixin {
  @override
  final List<String> sdks;

  @override
  final List<String> stageNames;

  @override
  final List<TravisJob> jobs;

  MonoConfig(this.sdks, this.stageNames, this.jobs);

  factory MonoConfig.parse(String package, Map<String, dynamic> monoYaml) {
    var unrecognizedKeys =
        (monoYaml.keys.toSet()..removeAll(_validKeys)).toList()..sort();

    if (unrecognizedKeys.isNotEmpty) {
      throw new ArgumentError(
          'Unrecognized keys $unrecognizedKeys in .mono_repo.yaml.'
          'Only $_validKeys are allowed.');
    }

    var sdks = (monoYaml['dart'] as List<String>)?.toList();
    if (sdks == null || sdks.isEmpty) {
      throw new ArgumentError(
          'At least one SDK version is required under "dart".');
    }

    // FYI: 'test' is default if there are no tasks defined
    var jobs = <TravisJob>[];

    var stagesYaml = ((monoYaml['stages'] as List<Map<String, dynamic>>) ??
        [
          {
            'unit_test': ['test']
          }
        ]);

    var stageNames = <String>[];
    for (var stage in stagesYaml) {
      if (stage.length != 1) {
        throw new ArgumentError(
            '`stages` expects a list of maps with exactly one key '
            '(the name of the stage). Got $stage.');
      }
      var stageName = stage.keys.first;
      if (stageNames.contains(stageName)) {
        throw new ArgumentError(
            'There should only be one entry for each stage, '
            'saw $stageName more than once.');
      }
      stageNames.add(stageName);
      for (var job in stage.values.first) {
        var jobSdks = sdks;
        if (job is Map<String, dynamic> && job.containsKey('dart')) {
          job = new Map<String, dynamic>.from(job as Map<String, dynamic>);
          jobSdks = job.remove('dart') as List<String>;
        }
        for (var sdk in jobSdks) {
          jobs.add(new TravisJob.parse(package, sdk, stageName, job));
        }
      }
    }

    return new MonoConfig(sdks, stageNames, jobs);
  }

  factory MonoConfig.fromJson(Map<String, dynamic> json) =>
      _$MonoConfigFromJson(json);

  static final _validKeys = const [
    'dart',
    'stages',
  ];
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
  final Task task;

  TravisJob(this.package, this.sdk, this.stageName, this.task);

  factory TravisJob.fromJson(Map<String, dynamic> json) =>
      _$TravisJobFromJson(json);

  factory TravisJob.parse(
      String package, String sdk, String stageName, Object yaml) {
    return new TravisJob(package, sdk, stageName, new Task.parse(yaml));
  }

  @override
  bool operator ==(Object other) =>
      other is TravisJob && _equality.equals(_items, other._items);

  @override
  int get hashCode => _equality.hash(_items);

  List get _items => [sdk, task];
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

  factory Task.parse(Object yamlValue) {
    if (yamlValue is String) {
      if (yamlValue == 'command') {
        throw new ArgumentError.value(yamlValue, 'command', 'requires a value');
      }
      return new Task(yamlValue);
    }

    if (yamlValue is Map<String, dynamic>) {
      var taskNames = yamlValue.keys.where(_tasks.contains).toList();
      if (taskNames.isEmpty || taskNames.length > 1) {
        throw new ArgumentError(
            'Must have one and only one key of $_prettyTaskList.');
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
