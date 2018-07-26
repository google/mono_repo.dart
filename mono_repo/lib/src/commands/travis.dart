// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:graphs/graphs.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../mono_config.dart';
import '../user_exception.dart';
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
      prettyAnsi: argResults['pretty-ansi'] as bool);
}

Future<Null> generateTravisConfig(
    {String rootDirectory,
    bool recursive = false,
    bool prettyAnsi = true}) async {
  rootDirectory ??= p.current;
  recursive ??= false;
  prettyAnsi ??= true;
  var configs =
      getMonoConfigs(rootDirectory: rootDirectory, recursive: recursive);

  _logPkgs(configs);

  var commandsToKeys = extractCommands(configs);

  _writeTravisYml(rootDirectory, configs, commandsToKeys);

  _writeTravisScript(rootDirectory,
      _calculateTaskEntries(commandsToKeys, prettyAnsi), prettyAnsi);
}

/// Write `.travis.yml`
void _writeTravisYml(String rootDirectory, Map<String, MonoConfig> configs,
    Map<String, String> commandsToKeys) {
  var travisPath = p.join(rootDirectory, travisFileName);
  var travisFile = new File(travisPath);
  travisFile.writeAsStringSync(_travisYml(configs, commandsToKeys));
  stderr.writeln(styleDim.wrap('Wrote `$travisPath`.'));
}

/// Write `tool/travis.sh`
void _writeTravisScript(
    String rootDirectory, List<String> taskEntries, bool prettyAnsi) {
  var travisFilePath = p.join(rootDirectory, travisShPath);
  var travisScript = new File(travisFilePath);

  if (!travisScript.existsSync()) {
    travisScript.createSync(recursive: true);
    stderr.writeln(
        yellow.wrap('Make sure to mark `$travisShPath` as executable.'));
    stderr.writeln(yellow.wrap('  chmod +x $travisShPath'));
  }

  travisScript.writeAsStringSync(_travisSh(taskEntries, prettyAnsi));
  // TODO: be clever w/ `travisScript.statSync().mode` to see if it's executable
  stderr.writeln(styleDim.wrap('Wrote `$travisFilePath`.'));
}

List<String> _calculateTaskEntries(
    Map<String, String> commandsToKeys, bool prettyAnsi) {
  var taskEntries = <String>[];

  void addEntry(String label, List<String> contentLines) {
    assert(contentLines.isNotEmpty);
    contentLines.add(';;');

    var buffer = new StringBuffer('  $label) ${contentLines.first}\n');
    buffer.writeAll(contentLines.skip(1).map((l) => '    $l'), '\n');

    var output = buffer.toString();
    if (!taskEntries.contains(output)) {
      taskEntries.add(output);
    }
  }

  commandsToKeys.forEach((command, taskKey) {
    addEntry(taskKey, [
      'echo',
      safeEcho(prettyAnsi, styleBold, 'TASK: $taskKey'),
      safeEcho(prettyAnsi, resetAll, command),
      '$command || EXIT_CODE=\$?',
    ]);
  });

  if (taskEntries.isEmpty) {
    throw new UserException(
        'No entries created. Check your nested `$monoFileName` files.');
  }

  taskEntries.sort();

  addEntry('*', [
    'echo -e "${_wrap(prettyAnsi, red, "Not expecting TASK '\${TASK}'. Error!")}"',
    'EXIT_CODE=1'
  ]);
  return taskEntries;
}

String _wrap(bool doWrap, AnsiCode code, String value) =>
    doWrap ? code.wrap(value, forScript: true) : value;

/// Gives a map of command to unique task key for all [configs].
Map<String, String> extractCommands(Map<String, MonoConfig> configs) {
  var commandsToKeys = <String, String>{};

  var tasksToConfigure = _travisTasks(configs);
  var taskNames = tasksToConfigure.map((task) => task.name).toSet();

  for (var taskName in taskNames) {
    var commands = tasksToConfigure
        .where((task) => task.name == taskName)
        .map((task) => task.command)
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

List<Task> _travisTasks(Map<String, MonoConfig> configs) => configs.values
    .expand((config) => config.jobs)
    .expand((job) => job.tasks)
    .toList();

void _logPkgs(Map<String, MonoConfig> configs) {
  for (var pkg in configs.keys) {
    stderr.writeln(styleBold.wrap('package:$pkg'));
  }
}

String _shellCase(String scriptVariable, List<String> entries) {
  if (entries.isEmpty) return '';
  return '''
  case \$$scriptVariable in
${entries.join('\n')}
  esac
''';
}

/// Safely escape everything:
/// 1 - use single quotes.
/// 2 - if there is a single quote in the string
///     2.1 end the before the single quote
///     2.2 echo the single quote escaped
///     2.3 continue the string
///
/// See https://stackoverflow.com/a/20053121/39827
String safeEcho(bool prettyAnsi, AnsiCode code, String value) {
  value = value.replaceAll("'", "'\\''");
  return "echo -e '${_wrap(prettyAnsi, code, value)}'";
}

String _travisSh(List<String> tasks, bool prettyAnsi) => '''
#!/bin/bash
# Created with https://github.com/dart-lang/mono_repo

if [ -z "\$PKG" ]; then
  ${safeEcho(prettyAnsi, red, "PKG environment variable must be set!")}
  exit 1
fi

if [ "\$#" == "0" ]; then
  ${safeEcho(prettyAnsi, red, "At least one task argument must be provided!")}
  exit 1
fi

pushd \$PKG
pub upgrade || exit \$?

EXIT_CODE=0

while (( "\$#" )); do
  TASK=\$1
${_shellCase('TASK', tasks)}
  shift
done

exit \$EXIT_CODE
''';

String _travisYml(
    Map<String, MonoConfig> configs, Map<String, String> commandsToKeys) {
  var orderedStages = _calculateOrderedStages(configs.values);
  var jobs = configs.values.expand((config) => config.jobs);

  var cacheDirs = _cacheDirs(configs).map((e) => '    - $e').join('\n');

  return '''
# Created with https://github.com/dart-lang/mono_repo
language: dart

jobs:
  include:
${_listJobs(jobs, commandsToKeys)}
stages:
${_listStages(orderedStages)}
# Only building master means that we don't run two builds for each pull request.
branches:
  only: [master]

cache:
  directories:
$cacheDirs
''';
}

Iterable<String> _cacheDirs(Map<String, MonoConfig> configs) {
  var items = new SplayTreeSet<String>()..add('\$HOME/.pub-cache');

  for (var entry in configs.entries) {
    for (var dir in entry.value.cacheDirectories) {
      items.add(p.posix.join(entry.key, dir));
    }
  }

  return items;
}

/// Calculates the global stages ordering, and throws a [UserException] if it
/// detects any cycles.
List<String> _calculateOrderedStages(Iterable<MonoConfig> configs) {
  // Convert the configs to a graph so we can run strongly connected components.
  var edges = <String, Set<String>>{};
  for (var config in configs) {
    String previous;
    for (var stage in config.stageNames) {
      edges.putIfAbsent(stage, () => new Set<String>());
      if (previous != null) {
        edges[previous].add(stage);
      }
      previous = stage;
    }
  }
  // Running strongly connected components lets us detect cycles (which aren't
  // allowed), and gives us the reverse order of what we ultimately want.
  var components =
      stronglyConnectedComponents(edges.keys, (n) => n, (n) => edges[n]);
  for (var component in components) {
    if (component.length > 1) {
      throw new UserException(
          'Not all packages agree on `stages` ordering, found '
          'a cycle between the following stages: $component');
    }
  }

  return components.map((c) => c.first).toList().reversed.toList();
}

String _listStages(Iterable<String> stages) {
  var buffer = new StringBuffer();
  for (var stage in stages) {
    buffer.writeln('  - $stage');
  }
  return buffer.toString();
}

/// Lists all the jobs, setting their stage, enviroment, and script.
String _listJobs(Iterable<TravisJob> jobs, Map<String, String> commandsToKeys) {
  var buffer = new StringBuffer();
  for (var job in jobs) {
    var commands =
        job.tasks.map((task) => commandsToKeys[task.command]).join(' ');
    var jobName = 'SDK: ${job.sdk}&nbsp;&nbsp;&nbsp;&nbsp;'
        'DIR: ${job.package}&nbsp;&nbsp;&nbsp;&nbsp;'
        'Description: ${job.name}';
    buffer.writeln('''
    - stage: ${job.stageName}
      name: "$jobName"
      script: ./tool/travis.sh $commands
      env: PKG="${job.package}"
      dart: ${job.sdk}''');
  }
  return buffer.toString();
}
