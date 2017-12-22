// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../travis_config.dart';
import '../utils.dart';

class TravisCommand extends Command<Null> {
  @override
  String get name => 'travis';

  @override
  String get description => 'Configure Travis-CI for child packages.';

  @override
  Future run() =>
      generateTravisConfig(recursive: globalResults[recursiveFlag] as bool);
}

Future generateTravisConfig(
    {String rootDirectory, bool recursive: false}) async {
  rootDirectory ??= p.current;
  var configs =
      getTravisConfigs(rootDirectory: rootDirectory, recursive: recursive);

  _logPkgs(configs);

  var sdks = _sdks(configs);
  var commandsToKeys = _extractCommands(configs);

  var environmentVars = new Map<String, Set<String>>();
  // Map from environment variable to SDKs for which failures are allowed
  var allowFailures = new Map<String, Set<String>>();

  _calculateEnvironment(
      configs, commandsToKeys, environmentVars, allowFailures);

  var taskEntries = _calculateTaskEntries(commandsToKeys);

  var envEntries = environmentVars.keys.toList()..sort();

  var matrix =
      _calculateMatrix(envEntries, environmentVars, sdks, allowFailures);

  _writeTravisYml(rootDirectory, sdks, envEntries, matrix);
  _writeTravisScript(rootDirectory, taskEntries);
}

/// Write `.travis.yml`
void _writeTravisYml(String rootDirectory, Set<String> sdks,
    List<String> envEntries, List<String> matrix) {
  var travisPath = p.join(rootDirectory, travisFileName);
  var travisFile = new File(travisPath);
  travisFile.writeAsStringSync(_travisYml(sdks, envEntries, matrix.join('\n')));
  stderr.writeln(styleDim.wrap('Wrote `$travisPath`.'));
}

/// Write `tool/travis.sh
void _writeTravisScript(String rootDirectory, List<String> taskEntries) {
  var travisFilePath = p.join(rootDirectory, travisShPath);
  var travisScript = new File(travisFilePath);

  if (!travisScript.existsSync()) {
    travisScript.createSync(recursive: true);
    stderr.writeln(
        yellow.wrap('Make sure to mark `$travisShPath` as executable.'));
    stderr.writeln(yellow.wrap('  chmod +x $travisShPath'));
  }

  travisScript.writeAsStringSync(_travisSh(taskEntries));
  // TODO: be clever w/ `travisScript.statSync().mode` to see if it's executable
  stderr.writeln(styleDim.wrap('Wrote `$travisFilePath`.'));
}

void _calculateEnvironment(
    Map<String, TravisConfig> configs,
    Map<String, String> commandsToKeys,
    Map<String, Set<String>> environmentVars,
    Map<String, Set<String>> allowFailures) {
  configs.forEach((pkg, config) {
    for (var job in config.travisJobs) {
      var newVar = 'PKG=${pkg} TASK=${commandsToKeys[job.task.command]}';
      environmentVars.putIfAbsent(newVar, () => new Set<String>()).add(job.sdk);

      if (config.allowFailures.contains(job)) {
        allowFailures.putIfAbsent(newVar, () => new Set<String>()).add(job.sdk);
      }
    }
  });
}

List<String> _calculateMatrix(
    List<String> envEntries,
    Map<String, Set<String>> environmentVars,
    Set<String> sdks,
    Map<String, Set<String>> allowFailures) {
  var matrix = <String>[];

  matrix.addAll(_calculateExcluded(envEntries, environmentVars, sdks));
  matrix.addAll(_calculateAllowedFailures(allowFailures));

  if (matrix.isNotEmpty) {
    // Ensure there is a trailing newline after the matrix
    matrix.add('');
  }
  return matrix;
}

List<String> _calculateAllowedFailures(Map<String, Set<String>> allowFailures) {
  var matrix = <String>[];

  var firstAllow = true;
  var allowFailuresEntries = allowFailures.keys.toList()..sort();
  for (var envVarEntry in allowFailuresEntries) {
    var failureSdks = allowFailures[envVarEntry];

    if (failureSdks == null) {
      continue;
    }

    assert(failureSdks.isNotEmpty);
    if (matrix.isEmpty) {
      matrix.addAll(['', 'matrix:']);
    }

    if (firstAllow) {
      firstAllow = false;
      matrix.add('  allow_failures:');
    }

    for (var sdk in failureSdks) {
      matrix.add('    - dart: $sdk');
      matrix.add('      env: $envVarEntry');
    }
  }

  return matrix;
}

List<String> _calculateExcluded(List<String> envEntries,
    Map<String, Set<String>> environmentVars, Set<String> sdks) {
  var matrix = <String>[];

  /// Iterate in the already sorted order instead of using `forEach`.
  for (var envVarEntry in envEntries) {
    var entrySdks = environmentVars[envVarEntry];
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
  }
}

List<String> _calculateTaskEntries(Map<String, String> commandsToKeys) {
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

  commandsToKeys.forEach((command, taskKey) {
    addEntry(taskKey,
        ['echo', 'echo -e "${styleBold.wrap("TASK: $taskKey")}"', command]);
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
  return taskEntries;
}

Map<String, String> _extractCommands(Map<String, TravisConfig> configs) {
  var commandsToKeys = <String, String>{};

  for (var task in _travisTasks(configs)) {
    if (commandsToKeys.containsKey(task.command)) {
      continue;
    }

    var taskKey = task.name;

    var count = 1;
    while (commandsToKeys.containsValue(taskKey)) {
      taskKey = '${task.name}_${count++}';
    }

    commandsToKeys[task.command] = taskKey;
  }
  return commandsToKeys;
}

Iterable<DartTask> _travisTasks(Map<String, TravisConfig> configs) =>
    configs.values.expand((tc) => tc.travisJobs).map((tj) => tj.task);

Set<String> _sdks(Map<String, TravisConfig> configs) =>
    (configs.values.expand((tc) => tc.sdks).toList()..sort()).toSet();

void _logPkgs(Map<String, TravisConfig> configs) {
  for (var pkg in configs.keys) {
    stderr.writeln(styleBold.wrap('package:$pkg'));
  }
}

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
script: $travisShPath

# Only building master means that we don't run two builds for each pull request.
branches:
  only: [master]

cache:
 directories:
   - \$HOME/.pub-cache
''';
