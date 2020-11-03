import 'dart:collection';

import 'package:collection/collection.dart' hide stronglyConnectedComponents;
import 'package:graphs/graphs.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../../ci_shared.dart';
import '../../package_config.dart';
import '../../root_config.dart';
import '../../user_exception.dart';
import '../../version.dart';
import '../../yaml.dart';
import '../travis.dart';

String generateTravisYml(
  RootConfig rootConfig,
  Map<String, String> commandsToKeys,
) {
  final orderedStages = _calculateOrderedStages(rootConfig);

  for (var config in rootConfig) {
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
      print(
        yellow.wrap(
          '  There are jobs defined that are not compatible with '
          'the package SDK constraint ($sdkConstraint): $disallowedString.',
        ),
      );
    }
  }

  final jobs = rootConfig.expand((config) => config.jobs);

  var customTravis = '';
  if (rootConfig.monoConfig.travis.isNotEmpty) {
    customTravis = '\n# Custom configuration\n'
        '${toYaml(rootConfig.monoConfig.travis)}\n';
  }

  final branchConfig = rootConfig.monoConfig.travis.containsKey('branches')
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

  final jobList = [
    ..._listJobs(jobs, commandsToKeys, rootConfig.monoConfig.mergeStages),
    if (rootConfig.monoConfig.selfValidateStage != null)
      _selfValidateTaskConfig(rootConfig.monoConfig.selfValidateStage),
  ]..sort((a, b) {
      var value = stageIndex(a['stage']).compareTo(stageIndex(b['stage']));

      for (var key in const ['env', 'script', 'dart', 'os']) {
        if (value != 0) {
          break;
        }
        final aVal = a[key];
        final bVal = b[key];
        if (aVal == null) {
          if (bVal == null) {
            value = 0;
          } else {
            // null (a) first
            value = -1;
          }
        } else {
          if (bVal == null) {
            // null (b) first
            value = 1;
          } else {
            value = aVal.compareTo(bVal);
          }
        }
      }
      return value;
    });

  return '''
${createdWith()}${toYaml({'language': 'dart'})}
$customTravis
${toYaml({
    'jobs': {'include': jobList}
  })}

${toYaml({'stages': orderedStages})}
$branchConfig
${toYaml({
    'cache': {'directories': _cacheDirs(rootConfig)}
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

  String previous;
  for (var stage in rootConfig.monoConfig.conditionalStages.keys) {
    edges.putIfAbsent(stage, () => <String>{});
    if (previous != null) {
      edges[previous].add(stage);
    }
    previous = stage;
  }

  final rootMentionedStages = <String>{
    ...rootConfig.monoConfig.conditionalStages.keys,
    ...rootConfig.monoConfig.mergeStages,
  };

  for (var config in rootConfig) {
    String previous;
    for (var stage in config.stageNames) {
      rootMentionedStages.remove(stage);
      edges.putIfAbsent(stage, () => <String>{});
      if (previous != null) {
        edges[previous].add(stage);
      }
      previous = stage;
    }
  }

  if (rootMentionedStages.isNotEmpty) {
    final items = rootMentionedStages.map((e) => '`$e`').join(', ');

    throw UserException(
      'Error parsing mono_repo.yaml',
      details: 'One or more stage was referenced in `mono_repo.yaml` that do '
          'not exist in any `mono_pkg.yaml` files: $items.',
    );
  }

  // Running strongly connected components lets us detect cycles (which aren't
  // allowed), and gives us the reverse order of what we ultimately want.
  final components = stronglyConnectedComponents(edges.keys, (n) => edges[n]);
  for (var component in components) {
    if (component.length > 1) {
      final items = component.map((e) => '`$e`').join(', ');
      throw UserException(
        'Not all packages agree on `stages` ordering, found '
        'a cycle between the following stages: $items.',
      );
    }
  }

  final orderedStages = components
      .map((c) {
        final stageName = c.first;

        final matchingStage =
            rootConfig.monoConfig.conditionalStages[stageName];

        return matchingStage?.toJson() ?? stageName;
      })
      .toList()
      .reversed
      .toList();

  if (rootConfig.monoConfig.selfValidateStage != null &&
      !orderedStages.contains(rootConfig.monoConfig.selfValidateStage)) {
    orderedStages.insert(0, rootConfig.monoConfig.selfValidateStage);
  }

  return orderedStages;
}

/// Lists all the jobs, setting their stage, environment, and script.
Iterable<Map<String, String>> _listJobs(
  Iterable<CIJob> jobs,
  Map<String, String> commandsToKeys,
  Set<String> mergeStages,
) sync* {
  final jobEntries = <CIJobEntry>[];

  for (var job in jobs) {
    final commands =
        job.tasks.map((task) => commandsToKeys[task.command]).toList();

    jobEntries.add(CIJobEntry(job, commands));
  }

  // Group jobs by all of the values that would allow them to merge
  final groupedItems = groupBy<CIJobEntry, String>(
      jobEntries,
      (e) => [
            e.job.os,
            e.job.stageName,
            e.job.sdk,
            // TODO: sort these? Would merge jobs with different orders
            e.commands,
          ].join(':::'));

  for (var entry in groupedItems.entries) {
    final first = entry.value.first;
    if (mergeStages.contains(first.job.stageName)) {
      final packages = entry.value.map((t) => t.job.package).toList();
      yield first.jobYaml(packages);
    } else {
      yield* entry.value.map((jobEntry) => jobEntry.jobYaml());
    }
  }
}

extension on CIJobEntry {
  Map<String, String> jobYaml([List<String> packages]) {
    packages ??= [job.package];
    assert(packages.isNotEmpty);
    assert(packages.contains(job.package));

    return {
      'stage': job.stageName,
      'name': jobName(packages),
      'dart': job.sdk,
      'os': job.os,
      'env': 'PKGS="${packages.join(' ')}"',
      'script': '$travisShPath ${commands.join(' ')}',
    };
  }
}

Map<String, String> _selfValidateTaskConfig(String stageName) => {
      'stage': stageName,
      'name': 'mono_repo self validate',
      'os': 'linux',
      'script': 'pub global activate mono_repo $packageVersion && '
          'pub global run mono_repo travis --validate'
    };
