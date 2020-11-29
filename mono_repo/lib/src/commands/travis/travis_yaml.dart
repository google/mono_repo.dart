// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../ci_shared.dart';
import '../../package_config.dart';
import '../../root_config.dart';
import '../../yaml.dart';
import '../ci_script/generate.dart';

String generateTravisYml(
  RootConfig rootConfig,
  Map<String, String> commandsToKeys,
) {
  final orderedStages = calculateOrderedStages(
      rootConfig, rootConfig.monoConfig.travisConditionalStages);

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

  final jobList = [
    ..._listJobs(jobs, commandsToKeys, rootConfig.monoConfig.mergeStages),
    if (rootConfig.monoConfig.selfValidateStage != null)
      _selfValidateTaskConfig(rootConfig.monoConfig.selfValidateStage),
  ]..sort((a, b) {
      var value = orderedStages
          .indexOf(a['stage'])
          .compareTo(orderedStages.indexOf(b['stage']));

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

  final stageConfigs = orderedStages.map((stage) {
    final conditional = rootConfig.monoConfig.travisConditionalStages[stage];
    return conditional == null ? stage : conditional.toJson();
  }).toList();

  return '''
$createdWith
${toYaml({'language': 'dart'})}
$customTravis
${toYaml({
    'jobs': {'include': jobList}
  })}

${toYaml({'stages': stageConfigs})}
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

  final differentPackages = <String>{};
  final differentSdks = <String>{};

  for (var entry in jobEntries) {
    differentPackages.add(entry.job.package);
    differentSdks.add(entry.job.sdk);
  }

  final groupedItems = groupCIJobEntries(jobEntries);

  for (var entry in groupedItems.entries) {
    final first = entry.value.first;
    if (mergeStages.contains(first.job.stageName)) {
      final packages = entry.value.map((t) => t.job.package).toList();
      yield first.jobYaml(
        packages: packages,
        oneSdk: differentSdks.length == 1,
        onePackage: differentPackages.length == 1,
      );
    } else {
      yield* entry.value.map((jobEntry) => jobEntry.jobYaml(
            oneSdk: differentSdks.length == 1,
            onePackage: differentPackages.length == 1,
          ));
    }
  }
}

extension on CIJobEntry {
  Map<String, String> jobYaml({
    List<String> packages,
    @required bool oneSdk,
    @required bool onePackage,
  }) {
    packages ??= [job.package];
    assert(packages.isNotEmpty);
    assert(packages.contains(job.package));

    return {
      'stage': job.stageName,
      'name': jobName(
        packages,
        oneOs: true,
        oneSdk: oneSdk,
        onePackage: onePackage,
      ),
      'dart': job.sdk,
      'os': job.os,
      'env': 'PKGS="${packages.join(' ')}"',
      'script': '$ciScriptPath ${commands.join(' ')}',
    };
  }
}

Map<String, String> _selfValidateTaskConfig(String stageName) => {
      'stage': stageName,
      'name': selfValidateJobName,
      'os': 'linux',
      'script': selfValidateCommands.join(' && ')
    };
