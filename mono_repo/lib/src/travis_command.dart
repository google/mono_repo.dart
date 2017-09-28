import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

import 'travis_config.dart';
import 'utils.dart';

class TravisCommand extends Command {
  @override
  String get name => 'travis';

  @override
  String get description => 'Configure Travis-CI for child packages.';

  @override
  Future run() => generateTravisConfig();
}

Future generateTravisConfig({String rootDirectory}) async {
  rootDirectory ??= p.current;

  var packages = getPackageConfig(rootDirectory: rootDirectory);

  if (packages.isEmpty) {
    throw new UserException('No nested packages found.');
  }

  var configs = <String, TravisConfig>{};

  for (var pkg in packages.keys) {
    var travisPath = p.join(rootDirectory, pkg, travisFileName);
    var travisFile = new File(travisPath);

    if (travisFile.existsSync()) {
      var travisYaml =
          y.loadYaml(travisFile.readAsStringSync(), sourceUrl: travisPath);

      stderr.writeln(styleBold.wrap('package:$pkg'));
      var config = new TravisConfig.parse(travisYaml as Map<String, dynamic>);

      var configuredTasks =
          config.tasks.where((dt) => dt.config != null).toList();

      if (configuredTasks.isNotEmpty) {
        throw new UserException(
            'Tasks with fancy configuration are not supported. '
            'See `${p.relative(travisPath, from: rootDirectory)}`.');
      }

      configs[pkg] = config;
    }
  }

  var sdks = (configs.values.expand((tc) => tc.sdks).toList()..sort()).toSet();

  var taskToKeyMap = <DartTask, String>{};

  for (var task in configs.values
      .expand((tc) => tc.travisJobs)
      .map((tj) => tj.task)
      .toSet()) {
    assert(!taskToKeyMap.containsKey(task));
    var taskKey = task.name;

    var count = 1;
    while (taskToKeyMap.containsKey(taskKey)) {
      taskKey = '${task.name}_${count++}';
    }

    taskToKeyMap[task] = taskKey;
  }

  var environmentVars = new Map<String, Set<String>>();

  configs.forEach((pkg, config) {
    for (var job in config.travisJobs) {
      var newVar = 'PKG=${pkg} TASK=${taskToKeyMap[job.task]}';
      environmentVars.putIfAbsent(newVar, () => new Set<String>()).add(job.sdk);
    }
  });

  var taskEntries = <String>[];

  void addEntry(String label, List<String> contentLines) {
    assert(contentLines.isNotEmpty);
    contentLines.add(';;');

    var buffer = new StringBuffer('$label) ${contentLines.first}\n');
    buffer.writeAll(contentLines.skip(1).map((l) => '  $l'), '\n');

    var output = buffer.toString();
    if (!taskEntries.contains(output)) {
      taskEntries.add(output);
    }
  }

  taskToKeyMap.forEach((dartTask, taskKey) {
    addEntry(taskKey, [
      'echo',
      'echo -e "${styleBold.wrap("TASK: $taskKey")}"',
      dartTask.command
    ]);
  });

  if (taskEntries.isEmpty) {
    throw new UserException(
        'No entries created. Check your nested `$travisFileName` files.');
  }

  taskEntries.sort();

  addEntry('*', [
    'echo -e "${red.wrap("Not expecting TASK '\${TASK}'. Error!")}"',
    'exit 1'
  ]);

  var envEntries = environmentVars.keys.toList()..sort();

  var matrix = [];
  environmentVars.forEach((envVarEntry, entrySdks) {
    var excludeSdks = sdks.toSet()..removeAll(entrySdks);

    if (excludeSdks.isNotEmpty) {
      if (matrix.isEmpty) {
        matrix.addAll(['', 'matrix:', '  exclude:']);
      }

      for (var sdk in excludeSdks) {
        matrix.add('    - dart: $sdk');
        matrix.add('      env: $envVarEntry');
      }
    }
  });

  if (matrix.isNotEmpty) {
    // Ensure there is a trailing newline after the matrix
    matrix.add('');
  }

  //
  // Write `.travis.yml`
  //
  var travisPath = p.join(rootDirectory, travisFileName);
  var travisFile = new File(travisPath);
  travisFile.writeAsStringSync(_travisYml(sdks, envEntries, matrix.join('\n')));
  stderr.writeln(styleDim.wrap('Wrote `$travisPath`.'));

  //
  // Write `tool/travis.sh`
  //
  var travisFilePath = p.join(rootDirectory, _travisShPath);
  var travisScript = new File(travisFilePath);

  if (!travisScript.existsSync()) {
    travisScript.createSync(recursive: true);
    stderr.writeln(
        yellow.wrap('Make sure to mark `$_travisShPath` as executable.'));
    stderr.writeln(yellow.wrap('  chmod +x $_travisShPath'));
  }

  travisScript.writeAsStringSync(_travisSh(taskEntries));
  // TODO: be clever w/ `travisScript.statSync().mode` to see if it's executable
  stderr.writeln(styleDim.wrap('Wrote `$travisFilePath`.'));
}

final _travisShPath = './tool/travis.sh';

String _indentAndJoin(Iterable<String> items) =>
    items.map((i) => '  - $i').join('\n');

String _travisSh(Iterable<String> tasks) => '''
#!/bin/bash
# Created with https://github.com/dart-lang/mono_repo

# Fast fail the script on failures.
set -e

if [ -z "\$PKG" ]; then
  echo -e "${red.wrap("PKG environment variable must be set!")}"
  exit 1
elif [ -z "\$TASK" ]; then
  echo -e "${red.wrap("TASK environment variable must be set!")}"
  exit 1
fi

pushd \$PKG
pub upgrade

case \$TASK in
${tasks.join('\n')}
esac
''';

String _travisYml(
        Iterable<String> sdks, Iterable<String> envs, String matrix) =>
    '''
# Created with https://github.com/dart-lang/mono_repo
language: dart

dart:
${_indentAndJoin(sdks)}

env:
${_indentAndJoin(envs)}
$matrix
script: $_travisShPath

# Only building master means that we don't run two builds for each pull request.
branches:
  only: [master]

cache:
 directories:
   - \$HOME/.pub-cache
''';
