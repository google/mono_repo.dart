// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:io';

import 'package:graphs/graphs.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../mono_config.dart';
import '../package_config.dart';
import '../root_config.dart';
import '../shell_utils.dart';
import '../user_exception.dart';
import '../version.dart';
import '../yaml.dart';
import 'mono_repo_command.dart';

String _createdWith(String pkgVersion) =>
    'Created with package:mono_repo v$pkgVersion';

class TravisCommand extends MonoRepoCommand {
  @override
  String get name => 'travis';

  @override
  String get description => 'Configure Travis-CI for child packages.';

  TravisCommand() : super() {
    argParser.addFlag(
      'pretty-ansi',
      abbr: 'p',
      defaultsTo: true,
      help: 'If the generated `$travisShPath` file should include ANSI escapes '
          'to improve output readability.',
    );
  }

  @override
  void run() => generateTravisConfig(rootConfig(),
      prettyAnsi: argResults['pretty-ansi'] as bool);
}

void generateTravisConfig(
  RootConfig configs, {
  bool prettyAnsi = true,
  String pkgVersion,
}) {
  prettyAnsi ??= true;
  pkgVersion ??= packageVersion;

  _logPkgs(configs);

  final commandsToKeys = extractCommands(configs);

  _writeTravisYml(configs.rootDirectory, configs, commandsToKeys, pkgVersion);

  _writeTravisScript(
      configs.rootDirectory,
      _calculateTaskEntries(commandsToKeys, prettyAnsi),
      prettyAnsi,
      pkgVersion);
}

/// Write `.travis.yml`
void _writeTravisYml(String rootDirectory, RootConfig configs,
    Map<String, String> commandsToKeys, String pkgVersion) {
  final travisPath = p.join(rootDirectory, travisFileName);
  File(travisPath)
      .writeAsStringSync(_travisYml(configs, commandsToKeys, pkgVersion));
  print(styleDim.wrap('Wrote `$travisPath`.'));
}

/// Write `tool/travis.sh`
void _writeTravisScript(String rootDirectory, List<String> taskEntries,
    bool prettyAnsi, String pkgVersion) {
  final travisFilePath = p.join(rootDirectory, travisShPath);
  final travisScript = File(travisFilePath);

  if (!travisScript.existsSync()) {
    travisScript.createSync(recursive: true);
    print(yellow.wrap('Make sure to mark `$travisShPath` as executable.'));
    print(yellow.wrap('  chmod +x $travisShPath'));
  }

  travisScript
      .writeAsStringSync(_travisSh(taskEntries, prettyAnsi, pkgVersion));
  // TODO: be clever w/ `travisScript.statSync().mode` to see if it's executable
  print(styleDim.wrap('Wrote `$travisFilePath`.'));
}

List<String> _calculateTaskEntries(
    Map<String, String> commandsToKeys, bool prettyAnsi) {
  final taskEntries = <String>[];

  void addEntry(String label, List<String> contentLines) {
    assert(contentLines.isNotEmpty);
    contentLines.add(';;');

    final buffer = StringBuffer('  $label) ${contentLines.first}\n')
      ..writeAll(contentLines.skip(1).map((l) => '    $l'), '\n');

    final output = buffer.toString();
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
    throw UserException(
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
  final commandsToKeys = <String, String>{};

  final tasksToConfigure = _travisTasks(configs);
  final taskNames = tasksToConfigure.map((task) => task.name).toSet();

  for (var taskName in taskNames) {
    final commands = tasksToConfigure
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
    print(styleBold.wrap('package:${pkg.relativePath}'));
    if (pkg.sdks != null && !pkg.dartSdkConfigUsed) {
      print(yellow.wrap('  `dart` values (${pkg.sdks.join(', ')}) are not used '
          'and can be removed.'));
    }
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

String _travisSh(List<String> tasks, bool prettyAnsi, String pkgVersion) => '''
#!/bin/bash
# ${_createdWith(pkgVersion)}

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
    RootConfig configs, Map<String, String> commandsToKeys, String pkgVersion) {
  final orderedStages = _calculateOrderedStages(configs);
  final jobs = configs.expand((config) => config.jobs);

  var customTravis = '';
  if (configs.monoConfig.travis.isNotEmpty) {
    customTravis = '\n# Custom configuration\n'
        '${toYaml(configs.monoConfig.travis)}\n';
  }

  final branchConfig = configs.monoConfig.travis.containsKey('branches')
      ? ''
      : '''
\n# Only building master means that we don't run two builds for each pull request.
${toYaml({
          'branches': {
            'only': ['master']
          }
        })}
''';

  return '''
# ${_createdWith(pkgVersion)}
${toYaml({'language': 'dart'})}
$customTravis
${toYaml({
    'jobs': {'include': _listJobs(jobs, commandsToKeys)}
  })}

${toYaml({'stages': orderedStages})}
$branchConfig
${toYaml({
    'cache': {'directories': _cacheDirs(configs)}
  })}
''';
}

Iterable<String> _cacheDirs(Iterable<PackageConfig> configs) {
  final items = SplayTreeSet<String>()..add('\$HOME/.pub-cache');

  for (var entry in configs) {
    for (var dir in entry.cacheDirectories) {
      items.add(p.posix.join(entry.relativePath, dir));
    }
  }

  return items;
}

/// Calculates the global stages ordering, and throws a [UserException] if it
/// detects any cycles.
List<Object> _calculateOrderedStages(RootConfig rootConfig) {
  // Convert the configs to a graph so we can run strongly connected components.
  final edges = <String, Set<String>>{};
  for (var config in rootConfig) {
    String previous;
    for (var stage in config.stageNames) {
      edges.putIfAbsent(stage, () => Set<String>());
      if (previous != null) {
        edges[previous].add(stage);
      }
      previous = stage;
    }
  }
  // Running strongly connected components lets us detect cycles (which aren't
  // allowed), and gives us the reverse order of what we ultimately want.
  final components = stronglyConnectedComponents(edges.keys, (n) => edges[n]);
  for (var component in components) {
    if (component.length > 1) {
      throw UserException('Not all packages agree on `stages` ordering, found '
          'a cycle between the following stages: $component');
    }
  }

  final conditionalStages = Map<String, ConditionalStage>.from(
      rootConfig.monoConfig.conditionalStages);

  final orderedStages = components
      .map((c) {
        final stageName = c.first;

        final matchingStage = conditionalStages.remove(stageName);
        if (matchingStage != null) {
          return matchingStage.toJson();
        }

        return stageName;
      })
      .toList()
      .reversed
      .toList();

  if (conditionalStages.isNotEmpty) {
    throw UserException('Error parsing mono_repo.yaml',
        details: 'Stage `${conditionalStages.keys.first}` was referenced in '
            '`mono_repo.yaml`, but it does not exist in any '
            '`mono_pkg.yaml` files.');
  }

  return orderedStages;
}

/// Lists all the jobs, setting their stage, environment, and script.
Iterable<Map<String, String>> _listJobs(
    Iterable<TravisJob> jobs, Map<String, String> commandsToKeys) sync* {
  for (var job in jobs) {
    final commands =
        job.tasks.map((task) => commandsToKeys[task.command]).join(' ');
    final jobName = 'SDK: ${job.sdk} - '
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
