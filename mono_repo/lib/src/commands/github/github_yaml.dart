// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart' hide stronglyConnectedComponents;
import 'package:io/ansi.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../ci_shared.dart';
import '../../package_config.dart';
import '../../root_config.dart';
import '../../user_exception.dart';
import '../../yaml.dart';
import '../ci_script/generate.dart';
import '../shared.dart';
import 'self_validate_job.dart';

Map<String, String> generateGitHubYml(
  RootConfig rootConfig,
  Map<String, String> commandsToKeys,
) {
  final jobs = rootConfig.expand((config) => config.jobs).toList();

  final selfValidateStage = rootConfig.monoConfig.selfValidateStage;
  if (selfValidateStage != null) {
    jobs.add(SelfValidateJob(selfValidateStage));
  }

  final allJobStages = jobs.map((e) => e.stageName).toSet();

  final output = <String, String>{};

  void doTheWork(
    String fileName,
    String workflowName,
    Iterable<CIJob> myJobs,
    MapEntry<String, Map<String, dynamic>> extraEntry,
  ) {
    if (output.containsKey(fileName)) {
      throw UnimplementedError('Need a better error here!');
    }
    _jobNameCache.clear();
    final jobList = Map.fromEntries([
      if (extraEntry != null) extraEntry,
      ..._listJobs(myJobs, commandsToKeys, rootConfig.monoConfig.mergeStages),
    ]);

    output[fileName] = '''
${createdWith()}${toYaml(rootConfig.monoConfig.github.generate(workflowName))}

${toYaml({'jobs': jobList})}
''';
  }

  final workflows = rootConfig.monoConfig.github.workflows;

  if (workflows != null) {
    for (var entry in workflows.entries) {
      final myJobs = jobs
          .where((element) => entry.value.stages.contains(element.stageName))
          .toList();

      if (myJobs.isEmpty) {
        // TODO: make this better. Refer to the location in source?
        // Move the check to parse time?
        throw UserException(
          'No jobs are defined for the provided stage names.',
        );
      }

      allJobStages.removeWhere(entry.value.stages.contains);

      doTheWork(entry.key, entry.value.name, myJobs, null);
    }
  }

  if (allJobStages.isNotEmpty) {
    doTheWork(
      'dart',
      'Dart CI',
      jobs.where((element) => allJobStages.contains(element.stageName)),
      null,
    );
  }

  return output;
}

/// Lists all the jobs, setting their stage, environment, and script.
Iterable<MapEntry<String, Map<String, dynamic>>> _listJobs(
  Iterable<CIJob> jobs,
  Map<String, String> commandsToKeys,
  Set<String> mergeStages,
) sync* {
  final jobEntries = <CIJobEntry>[];

  for (var job in jobs) {
    if (job is SelfValidateJob) {
      yield _selfValidateTaskConfig();
      continue;
    }

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

// TODO: refactor to eliminate global state!
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
