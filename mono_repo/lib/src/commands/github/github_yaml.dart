// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart' hide stronglyConnectedComponents;
import 'package:io/ansi.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../ci_shared.dart';
import '../../package_config.dart';
import '../../root_config.dart';
import '../../yaml.dart';
import '../ci_script/generate.dart';
import '../shared.dart';

String generateGitHubYml(
  RootConfig rootConfig,
  Map<String, String> commandsToKeys,
) {
  final jobs = rootConfig.expand((config) => config.jobs);

  final jobList = Map.fromEntries([
    if (rootConfig.monoConfig.selfValidateStage != null)
      _selfValidateTaskConfig(),
    ..._listJobs(jobs, commandsToKeys, rootConfig.monoConfig.mergeStages),
  ]);

  return '''
${createdWith()}${toYaml(rootConfig.monoConfig.github.generate())}

${toYaml({'jobs': jobList})}
''';
}

/// Lists all the jobs, setting their stage, environment, and script.
Iterable<MapEntry<String, Map<String, dynamic>>> _listJobs(
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

    if (first.job.sdk == 'be/raw/latest') {
      print(red.wrap('SKIPPING OS `be/raw/latest` TODO GET SUPPORT!'));
      continue;
    }

    if (mergeStages.contains(first.job.stageName)) {
      final packages = entry.value.map((t) => t.job.package).toList();
      yield first.jobYaml(packages);
    } else {
      yield* entry.value.map((jobEntry) => jobEntry.jobYaml());
    }
  }
}

final _jobNameCache = <String>{};

String _replace(String input) {
  _jobNameCache.add(input);
  return 'job_${_jobNameCache.length.toString().padLeft(3, '0')}';
}

extension on CIJobEntry {
  String _jobName(List<String> packages) {
    final pkgLabel = packages.length == 1 ? 'PKG' : 'PKGS';

    return 'OS: ${job.os}; SDK: ${job.sdk}; $pkgLabel: ${packages.join(', ')}; '
        'TASKS: ${job.name}';
  }

  String get _githubJobOs {
    switch (job.os) {
      case 'linux':
        return 'ubuntu-latest';
      case 'windows':
        return 'windows-latest';
      case 'osx':
      case 'macos':
        return 'macos-latest';
    }
    throw UnsupportedError('Not sure how to map `${job.os}` to GitHub!');
  }

  MapEntry<String, Map<String, dynamic>> jobYaml([List<String> packages]) {
    packages ??= [job.package];
    assert(packages.isNotEmpty);
    assert(packages.contains(job.package));

    return _githubJobYaml(
      _jobName(packages),
      _githubJobOs,
      job.sdk,
      {
        '$ciScriptPath ${commands.join(' ')}': {
          'PKGS': packages.join(' '),
          'TRAVIS_OS_NAME': job.os,
        }
      },
    );
  }
}

Map<String, dynamic> _createDartSetup(String sdk) {
  Map<String, String> withMap;

  Version realVersion;

  try {
    realVersion = Version.parse(sdk);
  } on FormatException {
    // noop
  }

  if (realVersion != null) {
    if (realVersion.isPreRelease) {
      throw UnsupportedError(
        'Unsupported Dart SDK configuration: `$sdk`.',
      );
    }
    withMap = {
      'release-channel': 'stable',
      'version': sdk,
    };
  } else if (sdk == 'dev') {
    withMap = {'release-channel': 'dev'};
  } else if (sdk == 'stable') {
    withMap = {'release-channel': 'stable', 'version': 'latest'};
  } else {
    throw UnsupportedError(
      'Unsupported Dart SDK configuration: `$sdk`.',
    );
  }

  final map = {
    'uses': 'cedx/setup-dart@v2',
    'with': withMap,
  };

  return map;
}

MapEntry<String, Map<String, dynamic>> _githubJobYaml(
        String jobName,
        String jobOs,
        String dartVersion,
        Map<String, Map<String, dynamic>> runCommands) =>
    MapEntry(_replace(jobName), {
      'name': jobName,
      'runs-on': jobOs,
      'steps': [
        _createDartSetup(dartVersion),
        {'run': 'dart --version'},
        {'uses': 'actions/checkout@v2'},
        for (var command in runCommands.entries)
          {
            if (command.value != null && command.value.isNotEmpty)
              'env': command.value,
            'run': command.key
          },
      ],
    });

MapEntry<String, Map<String, dynamic>> _selfValidateTaskConfig() =>
    _githubJobYaml(selfValidateJobName, 'ubuntu-latest', 'stable', {
      for (var command in selfValidateCommands) command: null,
    });
