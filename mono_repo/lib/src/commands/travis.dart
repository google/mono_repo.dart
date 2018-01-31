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

  TravisCommand() : super() {
    argParser
      ..addFlag(
        'pretty-ansi',
        abbr: 'p',
        defaultsTo: true,
        help:
            'If the generated `$travisShPath` file should include ANSI escapes '
            'to improve output readability.',
      );
  }

  @override
  Future<Null> run() => generateTravisConfig(
      recursive: globalResults[recursiveFlag] as bool,
      prettyAnsi: this.argResults['pretty-ansi'] as bool);
}

Future<Null> generateTravisConfig(
    {String rootDirectory,
    bool recursive: false,
    bool prettyAnsi: true}) async {
  rootDirectory ??= p.current;
  recursive ??= false;
  prettyAnsi ??= true;
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

  var envEntries = environmentVars.keys.toList()..sort();

  var matrix =
      _calculateMatrix(envEntries, environmentVars, sdks, allowFailures);

  _writeTravisYml(rootDirectory, sdks, envEntries, matrix);

  _writeTravisScript(
      rootDirectory,
      _calculateTaskEntries(commandsToKeys, prettyAnsi),
      _calculatePkgEntries(configs, prettyAnsi),
      prettyAnsi);
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
void _writeTravisScript(String rootDirectory, List<String> taskEntries,
    List<String> pkgEntries, bool prettyAnsi) {
  var travisFilePath = p.join(rootDirectory, travisShPath);
  var travisScript = new File(travisFilePath);

  if (!travisScript.existsSync()) {
    travisScript.createSync(recursive: true);
    stderr.writeln(
        yellow.wrap('Make sure to mark `$travisShPath` as executable.'));
    stderr.writeln(yellow.wrap('  chmod +x $travisShPath'));
  }

  travisScript
      .writeAsStringSync(_travisSh(taskEntries, pkgEntries, prettyAnsi));
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
      var newVar = 'PKG=$pkg TASK=${commandsToKeys[job.task.command]}';
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

  var excluded = _calculateExcluded(envEntries, environmentVars, sdks);
  if (excluded.isNotEmpty) {
    matrix.addAll(['', 'matrix:']);
    matrix.addAll(excluded);
  }
  var allowedFailures = _calculateAllowedFailures(allowFailures);
  if (allowedFailures.isNotEmpty) {
    if (matrix.isEmpty) {
      matrix.addAll(['', 'matrix:']);
    }
    matrix.addAll(allowedFailures);
  }

  if (matrix.isNotEmpty) {
    // Ensure there is a trailing newline after the matrix
    matrix.add('');
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
        matrix.add('  exclude:');
      }

      for (var sdk in excludeSdks) {
        matrix.add('    - dart: $sdk');
        matrix.add('      env: $envVarEntry');
      }
    }
  }
  return matrix;
}

List<String> _calculateAllowedFailures(Map<String, Set<String>> allowFailures) {
  var matrix = <String>[];

  var allowFailuresEntries = allowFailures.keys.toList()..sort();
  for (var envVarEntry in allowFailuresEntries) {
    var failureSdks = allowFailures[envVarEntry];

    if (failureSdks == null) {
      continue;
    }

    assert(failureSdks.isNotEmpty);
    if (matrix.isEmpty) {
      matrix.add('  allow_failures:');
    }

    for (var sdk in failureSdks) {
      matrix.add('    - dart: $sdk');
      matrix.add('      env: $envVarEntry');
    }
  }

  return matrix;
}

List<String> _calculateTaskEntries(
    Map<String, String> commandsToKeys, bool prettyAnsi) {
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
    addEntry(taskKey, [
      'echo',
      'echo -e "${_wrap(prettyAnsi, styleBold, "TASK: $taskKey")}"',
      command
    ]);
  });

  if (taskEntries.isEmpty) {
    throw new UserException(
        'No entries created. Check your nested `$travisFileName` files.');
  }

  taskEntries.sort();

  addEntry('*', [
    'echo -e "${_wrap(prettyAnsi, red,"Not expecting TASK '\${TASK}'. Error!")}"',
    'exit 1'
  ]);
  return taskEntries;
}

String _wrap(bool doWrap, AnsiCode code, String value) =>
    doWrap ? code.wrap(value, forScript: true) : value;

List<String> _calculatePkgEntries(
    Map<String, TravisConfig> configs, bool prettyAnsi) {
  var pkgEntries = <String>[];

  void addEntry(String label, List<String> contentLines) {
    assert(contentLines.isNotEmpty);
    contentLines.add(';;');

    var buffer = new StringBuffer('$label) ${contentLines.first}\n');
    buffer.writeAll(contentLines.skip(1).map((l) => '  $l'), '\n');

    var output = buffer.toString();
    if (!pkgEntries.contains(output)) {
      pkgEntries.add(output);
    }
  }

  for (var pkg in configs.keys) {
    var config = configs[pkg];
    if (config.beforeScript != null) {
      addEntry(pkg, [
        'echo',
        'echo -e "${_wrap(prettyAnsi, styleBold, "PKG: $pkg")}"',
        'echo -e "  Running `${config.beforeScript}`"',
        config.beforeScript
      ]);
    }
  }

  return pkgEntries;
}

Map<String, String> _extractCommands(Map<String, TravisConfig> configs) {
  var commandsToKeys = <String, String>{};

  var tasksToConfigure = _travisTasks(configs).toList();
  var taskNames = tasksToConfigure.map((dt) => dt.name).toSet();

  for (var taskName in taskNames) {
    var commands = tasksToConfigure
        .where((dt) => dt.name == taskName)
        .map((dt) => dt.command)
        .toSet();

    if (commands.length == 1) {
      commandsToKeys[commands.single] = taskName;
      continue;
    }

    // TODO: could likely use some clever `log` math here
    final paddingSize = (commands.length - 1).toString().length;

    var count = 0;
    for (var command in commands) {
      commandsToKeys[command] =
          '${taskName}_${count.toString().padLeft(paddingSize, '0')}';
      count++;
    }
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

String _shellCase(String scriptVariable, List<String> entries) {
  if (entries.isEmpty) return '';
  return '''

case \$$scriptVariable in
${entries.join('\n')}
esac
''';
}

String _travisSh(
        List<String> tasks, List<String> pkgEntries, bool prettyAnsi) =>
    '''
#!/bin/bash
# Created with https://github.com/dart-lang/mono_repo

# Fast fail the script on failures.
set -e

if [ -z "\$PKG" ]; then
  echo -e "${_wrap(prettyAnsi, red, "PKG environment variable must be set!")}"
  exit 1
elif [ -z "\$TASK" ]; then
  echo -e "${_wrap(prettyAnsi, red, "TASK environment variable must be set!")}"
  exit 1
fi

pushd \$PKG
pub upgrade
${_shellCase('PKG', pkgEntries)}${_shellCase('TASK', tasks)}''';

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
