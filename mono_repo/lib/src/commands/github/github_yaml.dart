// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:io/ansi.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../ci_shared.dart';
import '../../github_config.dart';
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
  ) {
    if (output.containsKey(fileName)) {
      throw UnsupportedError(
        'Should not get here – duplicate workflow "$fileName".',
      );
    }
    final jobList = Map.fromEntries(
      _listJobs(myJobs, commandsToKeys, rootConfig.monoConfig.mergeStages),
    );

    output[fileName] = '''
$createdWith
${toYaml(rootConfig.monoConfig.github.generate(workflowName))}

${toYaml({'jobs': jobList})}
''';
  }

  final workflows = rootConfig.monoConfig.github.workflows;

  if (workflows != null) {
    for (var entry in workflows.entries) {
      assert(entry.value.stages.isNotEmpty);
      final myJobs = {
        for (var entry in entry.value.stages)
          entry: jobs.where((element) => element.stageName == entry).toList(),
      };

      for (var jobEntry in myJobs.entries) {
        if (jobEntry.value.isEmpty) {
          throw UserException(
            'No jobs are defined for the stage "${jobEntry.key}" '
            'defined in GitHub workflow "${entry.key}".',
          );
        }
      }

      allJobStages.removeAll(entry.value.stages);

      populateJobs(
        entry.key,
        entry.value.name,
        myJobs.values.expand((element) => element),
      );
    }
  }

  if (allJobStages.isNotEmpty) {
    populateJobs(
      defaultGitHubWorkflowFileName,
      defaultGitHubWorkflowName,
      jobs.where((element) => allJobStages.contains(element.stageName)),
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

  var count = 0;

  MapEntry<String, Map<String, dynamic>> _jobEntry(
    Map<String, dynamic> content,
  ) =>
      MapEntry('job_${(++count).toString().padLeft(3, '0')}', content);

  for (var job in jobs) {
    if (job is _SelfValidateJob) {
      yield _jobEntry(_selfValidateTaskConfig());
      continue;
    }

    final ciJob = job as CIJob;

    final commands =
        ciJob.tasks.map((task) => commandsToKeys[task.command]).toList();

    jobEntries.add(CIJobEntry(ciJob, commands));
  }

  // Group jobs by all of the values that would allow them to merge
  final groupedItems = groupCIJobEntries(jobEntries);

  for (var entry in groupedItems.entries) {
    final first = entry.value.first;

    if (first.job.sdk == 'be/raw/latest') {
      print(red.wrap('SKIPPING OS `be/raw/latest` TODO GET SUPPORT!'));
      continue;
    }

    if (mergeStages.contains(first.job.stageName)) {
      final packages = entry.value.map((t) => t.job.package).toList();
      yield _jobEntry(first.jobYaml(packages));
    } else {
      yield* entry.value.map(
        (jobEntry) => _jobEntry(jobEntry.jobYaml()),
      );
    }
  }
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

  Map<String, dynamic> jobYaml([List<String> packages]) {
    packages ??= [job.package];
    assert(packages.isNotEmpty);
    assert(packages.contains(job.package));

    return _githubJobYaml(
      _jobName(packages),
      _githubJobOs,
      job.sdk,
      [
        _CommandEntry(
          '$ciScriptPath ${commands.join(' ')}',
          env: {
            'PKGS': packages.join(' '),
            'TRAVIS_OS_NAME': job.os,
          },
        )
      ],
      packages: packages,
      commandNames: commands,
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

Map<String, dynamic> _githubJobYaml(
  String jobName,
  String jobOs,
  String dartVersion,
  List<_CommandEntry> runCommands, {
  List<String> packages,
  List<String> commandNames,
}) =>
    {
      'name': jobName,
      'runs-on': jobOs,
      'steps': [
        _createDartSetup(dartVersion),
        {'run': 'dart --version'},
        {'uses': 'actions/checkout@v2'},
        _cacheEntry(
          jobOs,
          dartVersion,
          packages: packages,
          commandNames: commandNames,
        ),
        for (var command in runCommands) command.runContent,
      ],
    };

class _CommandEntry {
  final String run;
  final Map<String, String> env;

  _CommandEntry(
    this.run, {
    this.env,
  });

  Map<String, dynamic> get runContent => {
        if (env != null && env.isNotEmpty) 'env': env,
        'run': run,
      };
}

const _pubCacheHostedDir = '~/.pub-cache/hosted';

Map<String, dynamic> _cacheEntry(
  String os,
  String dartVersion, {
  List<String> packages,
  List<String> commandNames,
}) {
  final cacheKeyParts = [
    'os:$os',
    'pub-cache-hosted',
    'dart:$dartVersion',
    if (packages != null && packages.isNotEmpty)
      'packages:${packages.join('-')}',
    if (commandNames != null && commandNames.isNotEmpty)
      'commands:${commandNames.join('-')}'
  ];

  final restoreKeys = [
    for (var i = cacheKeyParts.length - 1; i > 0; i--)
      cacheKeyParts.take(i).join(';')
  ];

  return {
    'name': 'Cache $_pubCacheHostedDir',
    'uses': 'actions/cache@v2',
    'with': {
      'path': _pubCacheHostedDir,
      'key': cacheKeyParts.join(';'),
      'restore-keys': restoreKeys.join('\n'),
    }
  };
}

Map<String, dynamic> _selfValidateTaskConfig() => _githubJobYaml(
      selfValidateJobName,
      'ubuntu-latest',
      'stable',
      [
        for (var command in selfValidateCommands) _CommandEntry(command),
      ],
    );

/// Used as a place-holder so we can treat all jobs the same in certain
/// workflows.
class _SelfValidateJob implements HasStageName {
  @override
  final String stageName;

  _SelfValidateJob(this.stageName);
}
