import 'dart:collection';

import 'package:collection/collection.dart' hide stronglyConnectedComponents;
import 'package:graphs/graphs.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../../package_config.dart';
import '../../root_config.dart';
import '../../user_exception.dart';
import '../../yaml.dart';
import 'shared.dart';

String generateTravisYml(
  RootConfig configs,
  Map<String, String> commandsToKeys,
) {
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
      print(
        yellow.wrap(
          '  There are jobs defined that are not compatible with '
          'the package SDK constraint ($sdkConstraint): $disallowedString.',
        ),
      );
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

  final jobList = [
    ..._listJobs(jobs, commandsToKeys, configs.monoConfig.mergeStages),
    if (configs.monoConfig.selfValidate) _selfValidateTaskConfig,
  ]..sort((a, b) {
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
${createdWith()}${toYaml({'language': 'dart'})}
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

  if (rootConfig.monoConfig.selfValidate &&
      !orderedStages.contains(_selfValidateStageName)) {
    orderedStages.insert(0, _selfValidateStageName);
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
      yield* entry.value.map(
        (jobEntry) => jobEntry.jobYaml([jobEntry.job.package]),
      );
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
      'script': '$travisShPath ${commands.join(' ')}',
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

const _selfValidateStageName = 'mono_repo_self_validate';

const _selfValidateTaskConfig = {
  'stage': _selfValidateStageName,
  'name': 'mono_repo self validate',
  'os': 'linux',
  'script': travisSelfValidateScriptPath,
};
const _equality = DeepCollectionEquality();
