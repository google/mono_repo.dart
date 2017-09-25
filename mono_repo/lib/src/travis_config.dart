library mono_repo.travis_config;

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:io/ansi.dart';
import 'package:json_serializable/annotations.dart';
import 'package:yaml/yaml.dart' as y;

part 'travis_config.g.dart';

final travisFileName = '.travis.yml';

@JsonSerializable()
class TravisConfig extends Object with _$TravisConfigSerializerMixin {
  @override
  final String package;

  @override
  final List<String> sdks;

  @override
  final List<DartTask> tasks;

  @override
  final List<TravisJob> include, exclude;

  TravisConfig(this.package, this.sdks, this.tasks, this.include, this.exclude);

  factory TravisConfig.parse(String package, Map<String, dynamic> travisYaml) {
    stderr.writeln(styleBold.wrap('package:$package'));

    var ignoredKeys = travisYaml.keys.toSet()..removeAll(_processedKeys);

    if (ignoredKeys.isNotEmpty) {
      stderr.writeln(yellow.wrap('''  Ignoring these keys in `$travisFileName`:
${ignoredKeys.map((k) => '    $k').join('\n')}'''));
    }

    var sdks = travisYaml['dart'] as List<String>;

    var dartTasks = (travisYaml['dart_task'] as List)
        .map((yamlValue) => new DartTask.parse(yamlValue))
        .toList();

    var include = <TravisJob>[];
    var exclude = <TravisJob>[];

    var matrix = travisYaml['matrix'] as Map;

    if (matrix != null) {
      void processException(y.YamlList matrixItem, List<TravisJob> targetList) {
        if (matrixItem == null) {
          return;
        }

        for (y.YamlMap item in matrixItem) {
          var sdk = item['dart'] as String;
          if (sdk == null) {
            throw new ArgumentError('Matrix items require `dart` key.');
          }

          var taskValue = item['dart_task'];
          var task = new DartTask.parse(taskValue);

          targetList.add(new TravisJob(sdk, task));
        }
      }

      processException(matrix['include'] as y.YamlList, include);
      processException(matrix['exclude'] as y.YamlList, exclude);
    }

    return new TravisConfig(package, sdks, dartTasks, include, exclude);
  }

  Iterable<TravisJob> get travisJobs sync* {
    for (var sdk in sdks) {
      for (var task in tasks) {
        var job = new TravisJob(sdk, task);
        if (!exclude.contains(job)) {
          yield job;
        }
      }
    }

    yield* include;
  }

  factory TravisConfig.fromJson(Map<String, dynamic> json) =>
      _$TravisConfigFromJson(json);

  static final _processedKeys = const ['dart_task', 'dart', 'matrix'];
}

@JsonSerializable()
class TravisJob extends Object with _$TravisJobSerializerMixin {
  @override
  final String sdk;

  @override
  final DartTask task;

  TravisJob(this.sdk, this.task);

  factory TravisJob.fromJson(Map<String, dynamic> json) =>
      _$TravisJobFromJson(json);

  @override
  bool operator ==(Object other) =>
      other is TravisJob && _equality.equals(_items, other._items);

  @override
  int get hashCode => _equality.hash(_items);

  List get _items => [sdk, task];
}

@JsonSerializable(includeIfNull: false)
class DartTask extends Object with _$DartTaskSerializerMixin {
  static final _tasks = const ['dartfmt', 'dartanalyzer', 'test'];
  static final _prettyTaskList = _tasks.map((t) => '`$t`').join(', ');

  @override
  final String name;

  @override
  final String args;

  @override
  final Map<String, dynamic> config;

  DartTask(this.name, {this.args, this.config});

  factory DartTask.parse(Object yamlValue) {
    if (yamlValue is String) {
      return new DartTask(yamlValue);
    }

    if (yamlValue is Map<String, dynamic>) {
      var taskNames = yamlValue.keys.where((k) => _tasks.contains(k)).toList();
      if (taskNames.isEmpty || taskNames.length > 1) {
        throw new ArgumentError(
            'Must have one and only one key of $_prettyTaskList.');
      }
      var taskName = taskNames.single;
      var args = yamlValue[taskName] as String;

      var config = new Map<String, dynamic>.from(yamlValue);
      config.remove(taskName);

      if (config.isEmpty) {
        config = null;
      }
      return new DartTask(taskName, args: args, config: config);
    }

    throw new ArgumentError('huh? $yamlValue ${yamlValue.runtimeType}');
  }

  factory DartTask.fromJson(Map<String, dynamic> json) =>
      _$DartTaskFromJson(json);

  String get command {
    switch (name) {
      case 'dartfmt':
        assert(args == null || args == 'sdk');
        return 'dartfmt -n --set-exit-if-changed .';
      case 'dartanalyzer':
        assert(args == null);
        return 'dartanalyzer .';
      case 'test':
        var value = 'pub run test';
        if (args != null) {
          value = '$value $args';
        }
        return value;
      default:
        throw new UnsupportedError('Cannot generate the command for `$name`.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DartTask && _equality.equals(_items, other._items);

  @override
  int get hashCode => _equality.hash(_items);

  List get _items => [name, args, config];
}

final _equality = const DeepCollectionEquality.unordered();
