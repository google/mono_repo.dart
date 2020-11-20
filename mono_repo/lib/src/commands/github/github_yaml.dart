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

Map<String, String> generateGitHubYml(
  RootConfig rootConfig,
  Map<String, String> commandsToKeys,
) {
  final jobs = <HasStageName>[
    ...rootConfig.expand((config) => config.jobs),
  ];

  final selfValidateStage = rootConfig.monoConfig.selfValidateStage;
  if (selfValidateStage != null) {
    jobs.add(_SelfValidateJob(selfValidateStage));
  }

  final allJobStages = {for (var job in jobs) job.stageName};

  final output = <String, String>{};

  void populateJobs(
    String fileName,
    String workflowName,
    Iterable<HasStageName> myJobs,
    MapEntry<String, Map<String, dynamic>> extraEntry,
  ) {
    if (output.containsKey(fileName)) {
      throw UnimplementedError('Need a better error here!');
    }
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

      populateJobs(entry.key, entry.value.name, myJobs, null);
    }
  }

  if (allJobStages.isNotEmpty) {
    populateJobs(
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
  Iterable<HasStageName> jobs,
  Map<String, String> commandsToKeys,
  Set<String> mergeStages,
) sync* {
  final jobEntries = <CIJobEntry>[];

  for (var job in jobs) {
    if (job is _SelfValidateJob) {
      yield MapEntry(selfValidateJobName, _selfValidateTaskConfig());
      continue;
    }

    final ciJob = job as CIJob;

    final commands =
        ciJob.tasks.map((task) => commandsToKeys[task.command]).toList();

    jobEntries.add(CIJobEntry(ciJob, commands));
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

  var count = 0;

  for (var entry in groupedItems.entries) {
    final first = entry.value.first;

    if (first.job.sdk == 'be/raw/latest') {
      print(red.wrap('SKIPPING OS `be/raw/latest` TODO GET SUPPORT!'));
      continue;
    }

    if (mergeStages.contains(first.job.stageName)) {
      final packages = entry.value.map((t) => t.job.package).toList();
      yield MapEntry(_jobName(++count), first.jobYaml(packages));
    } else {
      yield* entry.value.map(
        (jobEntry) => MapEntry(_jobName(++count), jobEntry.jobYaml()),
      );
    }
  }
}

String _jobName(int count) => 'job_${count.toString().padLeft(3, '0')}';

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

  Map<String, dynamic> jobYaml([List<String> packages]) {
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

Map<String, dynamic> _githubJobYaml(String jobName, String jobOs,
        String dartVersion, Map<String, Map<String, dynamic>> runCommands) =>
    {
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
    };

Map<String, dynamic> _selfValidateTaskConfig() =>
    _githubJobYaml(selfValidateJobName, 'ubuntu-latest', 'stable', {
      for (var command in selfValidateCommands) command: null,
    });

/// Used as a place-holder so we can treat all jobs the same in certain
/// workflows.
class _SelfValidateJob implements HasStageName {
  @override
  final String stageName;

  _SelfValidateJob(this.stageName);
}
