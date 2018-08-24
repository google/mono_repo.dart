// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:graphs/graphs.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../package_config.dart';
import '../root_config.dart';
import '../shell_utils.dart';
import '../user_exception.dart';
import '../yaml.dart';
import 'mono_repo_command.dart';

class TravisCommand extends MonoRepoCommand {
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
  Future<Null> run() => generateTravisConfig(rootConfig(),
      prettyAnsi: argResults['pretty-ansi'] as bool);
}

Future<Null> generateTravisConfig(RootConfig configs,
    {bool prettyAnsi = true}) async {
  prettyAnsi ??= true;

  _logPkgs(configs);

  var commandsToKeys = extractCommands(configs);

  _writeTravisYml(configs.rootDirectory, configs, commandsToKeys);

  _writeTravisScript(configs.rootDirectory,
      _calculateTaskEntries(commandsToKeys, prettyAnsi), prettyAnsi);
}

/// Write `.travis.yml`
void _writeTravisYml(String rootDirectory, RootConfig configs,
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
        'No entries created. Check your nested `$monoPkgFileName` files.');
  }

  taskEntries.sort();

  addEntry('*', [
    'echo -e "${wrapAnsi(prettyAnsi, red, "Not expecting TASK '\${TASK}'. Error!")}"',
    'EXIT_CODE=1'
  ]);
  return taskEntries;
}

/// Gives a map of command to unique task key for all [configs].
Map<String, String> extractCommands(Iterable<PackageConfig> configs) {
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

List<Task> _travisTasks(Iterable<PackageConfig> configs) =>
    configs.expand((config) => config.jobs).expand((job) => job.tasks).toList();

void _logPkgs(Iterable<PackageConfig> configs) {
  for (var pkg in configs) {
    stderr.writeln(styleBold.wrap('package:${pkg.relativePath}'));
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

String _travisYml(RootConfig configs, Map<String, String> commandsToKeys) {
  var orderedStages = _calculateOrderedStages(configs);
  var jobs = configs.expand((config) => config.jobs);

  var customTravis = '';
  if (configs.monoConfig.travis.isNotEmpty) {
    customTravis = '\n# Custom configuration\n'
        '${toYaml(configs.monoConfig.travis)}\n';
  }

  return '''
# Created with https://github.com/dart-lang/mono_repo
${toYaml({'language': 'dart'})}
$customTravis
${toYaml({
    'jobs': {'include': _listJobs(jobs, commandsToKeys)}
  })}

${toYaml({'stages': orderedStages})}

# Only building master means that we don't run two builds for each pull request.
${toYaml({
    'branches': {
      'only': ['master']
    }
  })}

${toYaml({
    'cache': {'directories': _cacheDirs(configs)}
  })}
''';
}

Iterable<String> _cacheDirs(Iterable<PackageConfig> configs) {
  var items = new SplayTreeSet<String>()..add('\$HOME/.pub-cache');

  for (var entry in configs) {
    for (var dir in entry.cacheDirectories) {
      items.add(p.posix.join(entry.relativePath, dir));
    }
  }

  return items;
}

/// Calculates the global stages ordering, and throws a [UserException] if it
/// detects any cycles.
List<String> _calculateOrderedStages(Iterable<PackageConfig> configs) {
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

/// Lists all the jobs, setting their stage, enviroment, and script.
Iterable<Map<String, String>> _listJobs(
    Iterable<TravisJob> jobs, Map<String, String> commandsToKeys) sync* {
  for (var job in jobs) {
    var commands =
        job.tasks.map((task) => commandsToKeys[task.command]).join(' ');
    var jobName = 'SDK: ${job.sdk} - '
        'DIR: ${job.package} - '
        'TASKS: ${job.name}';

    yield {
      'stage': job.stageName,
      'name': jobName,
      'script': './tool/travis.sh $commands',
      'env': 'PKG="${job.package}"',
      'dart': job.sdk
    };
  }
}
