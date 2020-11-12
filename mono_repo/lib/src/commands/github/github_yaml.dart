import 'package:collection/collection.dart' hide stronglyConnectedComponents;
import 'package:io/ansi.dart';

import '../../ci_shared.dart';
import '../../package_config.dart';
import '../../root_config.dart';
import '../../yaml.dart';
import '../ci_script/generate.dart';

String generateGitHubYml(
  RootConfig rootConfig,
  Map<String, String> commandsToKeys,
) {
  validateRootConfig(rootConfig);

  final jobs = rootConfig.expand((config) => config.jobs);

  final jobList = Map<String, dynamic>.fromEntries(
      _listJobs(jobs, commandsToKeys, rootConfig.monoConfig.mergeStages)
          .map((e) => e.entries.single));

  return '''
${createdWith()}${toYaml({'name': 'Dart CI'})}

on:
  push:
    branches: [ master ]
  pull_request:

defaults:
  run:
    shell: bash

${toYaml({'jobs': jobList})}
''';
}

/// Lists all the jobs, setting their stage, environment, and script.
Iterable<Map<String, dynamic>> _listJobs(
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

extension on CIJobEntry {
  static final _jobNameCache = <String>{};

  static String _replace(String input) {
    _jobNameCache.add(input);
    return 'job_${_jobNameCache.length.toString().padLeft(3, '0')}';
  }

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
      case 'macos':
        return 'macos-latest';
    }
    throw UnsupportedError('Not sure how to map `${job.os}` to GitHub!');
  }

  Map<String, dynamic> get _dartSetup {
    Map<String, String> withMap;

    final realVersion = job.explicitSdkVersion;

    if (realVersion != null) {
      if (realVersion.isPreRelease) {
        throw UnsupportedError('Not sure how to party on `${job.sdk}`.');
      }
      withMap = {
        'release-channel': 'stable',
        'version': job.sdk,
      };
    } else if (job.sdk == 'dev') {
      withMap = {'release-channel': 'dev'};
    } else {
      throw UnsupportedError('Not sure how to party on `${job.sdk}`.');
    }

    final map = {
      'uses': 'cedx/setup-dart@v2',
      'with': withMap,
    };

    return map;
  }

  Map<String, dynamic> jobYaml([List<String> packages]) {
    packages ??= [job.package];
    assert(packages.isNotEmpty);
    assert(packages.contains(job.package));

    return {
      _replace(_jobName(packages)): {
        'name': _jobName(packages),
        'runs-on': _githubJobOs,
        'steps': [
          _dartSetup,
          {'uses': 'actions/checkout@v2'},
          {
            'env': {
              'PKGS': packages.join(' '),
              'TRAVIS_OS_NAME': job.os,
            },
            'run': '$ciScriptPath ${commands.join(' ')}',
          },
        ],
      }
    };
  }
}
