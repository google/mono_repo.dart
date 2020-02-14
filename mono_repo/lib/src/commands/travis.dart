// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart'
    show groupBy, DeepCollectionEquality;
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
    argParser
      ..addFlag(
        'pretty-ansi',
        abbr: 'p',
        defaultsTo: true,
        help:
            'If the generated `$travisShPath` file should include ANSI escapes '
            'to improve output readability.',
      )
      ..addFlag('use-get',
          defaultsTo: false,
          negatable: false,
          help:
              'If the generated `$travisShPath` file should use `pub get` for '
              'dependencies instead of `pub upgrade`.');
  }

  @override
  void run() => generateTravisConfig(rootConfig(),
      prettyAnsi: argResults['pretty-ansi'] as bool,
      useGet: argResults['use-get'] as bool);
}

void generateTravisConfig(
  RootConfig configs, {
  bool prettyAnsi = true,
  bool useGet = false,
  String pkgVersion,
}) {
  prettyAnsi ??= true;
  useGet ??= false;
  pkgVersion ??= packageVersion;

  _logPkgs(configs);

  final commandsToKeys = extractCommands(configs);

  _writeTravisYml(configs.rootDirectory, configs, commandsToKeys, pkgVersion);

  _writeTravisScript(
      configs.rootDirectory,
      _calculateTaskEntries(commandsToKeys, prettyAnsi),
      prettyAnsi,
      useGet ? 'get' : 'upgrade',
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
    bool prettyAnsi, String pubDependencyCommand, String pkgVersion) {
  final travisFilePath = p.join(rootDirectory, travisShPath);
  final travisScript = File(travisFilePath);

  if (!travisScript.existsSync()) {
    travisScript.createSync(recursive: true);
    print(yellow.wrap('Make sure to mark `$travisShPath` as executable.'));
    print(yellow.wrap('  chmod +x $travisShPath'));
    if (Platform.isWindows) {
      print(yellow.wrap('It appears you are using Windows, and may not have '
          'access to chmod.'));
      print(yellow.wrap('If you are using git, the following will emulate the '
          'Unix permissions change:'));
      print(yellow.wrap('  git update-index --add --chmod=+x $travisShPath'));
    }
  }

  travisScript.writeAsStringSync(
      _travisSh(taskEntries, prettyAnsi, pubDependencyCommand, pkgVersion));
  // TODO: be clever w/ `travisScript.statSync().mode` to see if it's executable
  print(styleDim.wrap('Wrote `$travisFilePath`.'));
}

List<String> _calculateTaskEntries(
    Map<String, String> commandsToKeys, bool prettyAnsi) {
  final taskEntries = <String>[];

  void addEntry(String label, List<String> contentLines) {
    assert(contentLines.isNotEmpty);
    contentLines.add(';;');

    final buffer = StringBuffer('$label)\n')
      ..writeAll(contentLines.map((l) => '  $l'), '\n');

    final output = buffer.toString();
    if (!taskEntries.contains(output)) {
      taskEntries.add(output);
    }
  }

  commandsToKeys.forEach((command, taskKey) {
    addEntry(taskKey, [
      "echo '${wrapAnsi(prettyAnsi, resetAll, command)}'",
      '$command || EXIT_CODE=\$?',
    ]);
  });

  if (taskEntries.isEmpty) {
    throw UserException(
        'No entries created. Check your nested `$monoPkgFileName` files.');
  }

  taskEntries.sort();

  final echoContent =
      wrapAnsi(prettyAnsi, red, "Not expecting TASK '\${TASK}'. Error!");
  addEntry('*', ['echo -e "$echoContent"', 'EXIT_CODE=1']);
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
    if (pkg.oses != null && !pkg.osConfigUsed) {
      print(yellow.wrap('  `os` values (${pkg.oses.join(', ')}) are not used '
          'and can be removed.'));
    }
  }
}

String _shellCase(String scriptVariable, List<String> entries) {
  if (entries.isEmpty) return '';
  return LineSplitter.split('''
case \${$scriptVariable} in
${entries.join('\n')}
esac
''').map((l) => '    $l').join('\n');
}

String _travisSh(List<String> tasks, bool prettyAnsi,
        String pubDependencyCommand, String pkgVersion) =>
    '''
#!/bin/bash
# ${_createdWith(pkgVersion)}

# Support built in commands on windows out of the box.
function pub {
       if [[ \$TRAVIS_OS_NAME == "windows" ]]; then
        command pub.bat "\$@"
    else
        command pub "\$@"
    fi
}
function dartfmt {
       if [[ \$TRAVIS_OS_NAME == "windows" ]]; then
        command dartfmt.bat "\$@"
    else
        command dartfmt "\$@"
    fi
}
function dartanalyzer {
       if [[ \$TRAVIS_OS_NAME == "windows" ]]; then
        command dartanalyzer.bat "\$@"
    else
        command dartanalyzer "\$@"
    fi
}

if [[ -z \${PKGS} ]]; then
  ${safeEcho(prettyAnsi, red, "PKGS environment variable must be set!")}
  exit 1
fi

if [[ "\$#" == "0" ]]; then
  ${safeEcho(prettyAnsi, red, "At least one task argument must be provided!")}
  exit 1
fi

EXIT_CODE=0

for PKG in \${PKGS}; do
  echo -e "\\033[1mPKG: \${PKG}\\033[22m"
  pushd "\${PKG}" || exit \$?

  PUB_EXIT_CODE=0
  pub $pubDependencyCommand --no-precompile || PUB_EXIT_CODE=\$?

  if [[ \${PUB_EXIT_CODE} -ne 0 ]]; then
    EXIT_CODE=1
    ${safeEcho(prettyAnsi, red, "pub $pubDependencyCommand failed")}
    popd
    continue
  fi

  for TASK in "\$@"; do
    echo
    echo -e "\\033[1mPKG: \${PKG}; TASK: \${TASK}\\033[22m"
${_shellCase('TASK', tasks)}
  done

  popd
done

exit \${EXIT_CODE}
''';

String _travisYml(
    RootConfig configs, Map<String, String> commandsToKeys, String pkgVersion) {
  final orderedStages = _calculateOrderedStages(configs);

  for (var config in configs) {
    final sdkConstraint = config.pubspec.environment['sdk'];

    if (sdkConstraint == null) {
      continue;
    }

    final disallowedExplicitVersions = config.jobs
        .map((tj) => tj.explicitSdkVersion)
        .where((v) => v != null)
        .toSet()
        .where((v) => !sdkConstraint.allows(v))
        .toList()
          ..sort();

    if (disallowedExplicitVersions.isNotEmpty) {
      final disallowedString =
          disallowedExplicitVersions.map((v) => '`$v`').join(', ');
      print(yellow.wrap('  There are jobs defined that are not compatible with '
          'the package SDK constraint ($sdkConstraint): $disallowedString.'));
    }
  }

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

  int stageIndex(String value) => orderedStages.indexWhere((e) {
        if (e is String) {
          return e == value;
        }

        return (e as Map)['name'] == value;
      });

  final jobList =
      _listJobs(jobs, commandsToKeys, configs.monoConfig.mergeStages).toList()
        ..sort((a, b) {
          var value = stageIndex(a['stage']).compareTo(stageIndex(b['stage']));

          if (value == 0) {
            value = a['env'].compareTo(b['env']);
          }
          if (value == 0) {
            value = a['script'].compareTo(b['script']);
          }
          if (value == 0) {
            value = a['dart'].compareTo(b['dart']);
          }
          if (value == 0) {
            value = a['os'].compareTo(b['os']);
          }
          return value;
        });

  return '''
# ${_createdWith(pkgVersion)}
${toYaml({'language': 'dart'})}
$customTravis
${toYaml({
    'jobs': {'include': jobList}
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
      edges.putIfAbsent(stage, () => <String>{});
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

  final unknownMergedStages = rootConfig.monoConfig.mergeStages.toSet();

  final orderedStages = components
      .map((c) {
        final stageName = c.first;

        unknownMergedStages.remove(stageName);

        final matchingStage = conditionalStages.remove(stageName);
        if (matchingStage != null) {
          return matchingStage.toJson();
        }

        return stageName;
      })
      .toList()
      .reversed
      .toList();

  if (unknownMergedStages.isNotEmpty) {
    throw UserException('Error parsing mono_repo.yaml',
        details: 'Stage `${unknownMergedStages.first}` was referenced in '
            '`mono_repo.yaml`, but it does not exist in any '
            '`mono_pkg.yaml` files.');
  }

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
  Iterable<TravisJob> jobs,
  Map<String, String> commandsToKeys,
  Set<String> mergeStages,
) sync* {
  final jobEntries = <_TravisJobEntry>[];

  for (var job in jobs) {
    final commands =
        job.tasks.map((task) => commandsToKeys[task.command]).toList();

    jobEntries.add(
        _TravisJobEntry(job, commands, mergeStages.contains(job.stageName)));
  }

  final groupedItems =
      groupBy<_TravisJobEntry, _TravisJobEntry>(jobEntries, (e) => e);

  for (var entry in groupedItems.entries) {
    if (entry.key.merge) {
      final packages = entry.value.map((t) => t.job.package).toList();
      yield entry.key.jobYaml(packages);
    } else {
      yield* entry.value
          .map((jobEntry) => jobEntry.jobYaml([jobEntry.job.package]));
    }
  }
}

class _TravisJobEntry {
  final TravisJob job;
  final List<String> commands;
  final bool merge;

  _TravisJobEntry(this.job, this.commands, this.merge);

  String _jobName(List<String> packages) {
    final pkgLabel = packages.length == 1 ? 'PKG' : 'PKGS';

    return 'SDK: ${job.sdk}; $pkgLabel: ${packages.join(', ')}; '
        'TASKS: ${job.name}';
  }

  Map<String, String> jobYaml(List<String> packages) {
    assert(packages.isNotEmpty);
    assert(packages.contains(job.package));

    return {
      'stage': job.stageName,
      'name': _jobName(packages),
      'dart': job.sdk,
      'os': job.os,
      'env': 'PKGS="${packages.join(' ')}"',
      'script': './tool/travis.sh ${commands.join(' ')}',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is _TravisJobEntry &&
      _equality.equals(_identityItems, other._identityItems);

  @override
  int get hashCode => _equality.hash(_identityItems);

  List get _identityItems => [job.os, job.stageName, job.sdk, commands, merge];
}

const _equality = DeepCollectionEquality();
