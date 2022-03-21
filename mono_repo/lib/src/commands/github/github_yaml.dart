// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../ci_shared.dart';
import '../../github_config.dart';
import '../../mono_config.dart';
import '../../package_config.dart';
import '../../root_config.dart';
import '../../user_exception.dart';
import '../../yaml.dart';

const _onCompletionStage = '_on_completion';

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
  final orderedStages = calculateOrderedStages(
      rootConfig, rootConfig.monoConfig.githubConditionalStages)
    ..add(_onCompletionStage);

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

    final sortedJobs = myJobs.toList()
      ..sort((a, b) {
        var value = orderedStages
            .indexOf(a.stageName)
            .compareTo(orderedStages.indexOf(b.stageName));

        if (value == 0) {
          if (a is _SelfValidateJob) {
            value = -1;
          }
          if (b is _SelfValidateJob) {
            value = 1;
          }
        }

        if (value == 0 && a is CIJob && b is CIJob) {
          value = a.sortBits.compareTo(b.sortBits);
        }
        assert(
          value != 0,
          ['Job sort not clear. Please file an issue!', a, b].join('\n'),
        );
        return value;
      });

    final allJobs = _listJobs(
      rootConfig,
      sortedJobs,
      commandsToKeys,
      rootConfig.monoConfig.mergeStages,
      rootConfig.monoConfig.github.onCompletion,
      rootConfig.monoConfig.githubConditionalStages,
    ).toList();

    var currStageJobs = <String>{};
    final allPrevStageJobs = <String>{};
    String? currStageName;
    for (var job in allJobs) {
      if (job.stageName != currStageName) {
        currStageName = job.stageName;
        allPrevStageJobs.addAll(currStageJobs);
        currStageJobs = {};
      }
      currStageJobs.add(job.key);
      if (allPrevStageJobs.isNotEmpty) {
        job.value['needs'] = allPrevStageJobs.toList();
      }
    }

    final jobList = Map.fromEntries(allJobs);

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
Iterable<_MapEntryWithStage> _listJobs(
  RootConfig rootConfig,
  List<HasStageName> jobs,
  Map<String, String> commandsToKeys,
  Set<String> mergeStages,
  List<Map<String, dynamic>>? onCompletionJobs,
  Map<String, ConditionalStage> conditionalStages,
) sync* {
  final jobEntries = <CIJobEntry>[];

  var count = 0;

  String jobName(int jobNum) => 'job_${jobNum.toString().padLeft(3, '0')}';

  _MapEntryWithStage jobEntry(
    Map<String, dynamic> content,
    String stage,
  ) {
    final conditional = conditionalStages[stage];
    if (conditional != null) {
      content['if'] = conditional.ifCondition;
    }
    return _MapEntryWithStage(jobName(++count), content, stage);
  }

  for (var job in jobs) {
    if (job is _SelfValidateJob) {
      yield jobEntry(_selfValidateTaskConfig(), job.stageName);
      continue;
    }

    final ciJob = job as CIJob;

    final commands =
        ciJob.tasks.map((task) => commandsToKeys[task.command]!).toList();

    jobEntries.add(CIJobEntry(ciJob, commands));
  }

  final differentOperatingSystems = <String>{};
  final differentPackages = <String>{};
  final differentSdks = <String>{};

  for (var entry in jobEntries) {
    differentOperatingSystems.add(entry.job.os);
    differentPackages.add(entry.job.package);
    differentSdks.add(entry.job.sdk);
  }

  // Group jobs by all of the values that would allow them to merge
  final groupedItems = groupCIJobEntries(jobEntries);

  for (var entry in groupedItems.entries) {
    final first = entry.value.first;

    if (mergeStages.contains(first.job.stageName)) {
      final packages = entry.value.map((t) => t.job.package).toList()..sort();
      yield jobEntry(
          first.jobYaml(
            rootConfig,
            packages: packages,
            oneOs: differentOperatingSystems.length == 1,
            oneSdk: differentSdks.length == 1,
            onePackage: differentPackages.length == 1,
          ),
          first.job.stageName);
    } else {
      yield* entry.value.map(
        (e) => jobEntry(
            e.jobYaml(
              rootConfig,
              oneOs: differentOperatingSystems.length == 1,
              oneSdk: differentSdks.length == 1,
              onePackage: differentPackages.length == 1,
            ),
            e.job.stageName),
      );
    }
  }

  // Generate the jobs that run on completion of all other jobs, by adding the
  // appropriate `needs` config to each.
  if (onCompletionJobs != null && onCompletionJobs.isNotEmpty) {
    for (var jobConfig in onCompletionJobs) {
      yield jobEntry({
        ...jobConfig,
      }, _onCompletionStage);
    }
  }
}

extension on CIJobEntry {
  String get _githubJobOs {
    switch (job.os) {
      case 'linux':
        return _ubuntuLatest;
      case 'windows':
        return 'windows-latest';
      case 'osx':
      case 'macos':
        return 'macos-latest';
    }
    throw UnsupportedError('Not sure how to map `${job.os}` to GitHub!');
  }

  Map<String, dynamic> jobYaml(
    RootConfig rootConfig, {
    List<String>? packages,
    required bool oneOs,
    required bool oneSdk,
    required bool onePackage,
  }) {
    packages ??= [job.package];
    assert(packages.isNotEmpty);
    assert(packages.contains(job.package));
    final pubCommand =
        '${job.flavor.pubCommand} ${rootConfig.monoConfig.pubAction}';

    final commandEntries = <_CommandEntry>[];
    for (var package in packages) {
      final pubStepId = '${package.replaceAll('/', '_')}_'
          'pub_${rootConfig.monoConfig.pubAction}';
      commandEntries.add(_CommandEntry(
        '$package; $pubCommand',
        pubCommand,
        id: pubStepId,
        // Run this regardless of the success of other steps other than the
        // pub step.
        ifCondition: "always() && steps.checkout.conclusion == 'success'",
        workingDirectory: package,
      ));
      for (var i = 0; i < commands.length; i++) {
        commandEntries.add(_CommandEntry(
          '$package; ${job.tasks[i].command}',
          _commandForOs(job.tasks[i].command),
          // Run this regardless of the success of other steps other than the
          // pub step.
          ifCondition: "always() && steps.$pubStepId.conclusion == 'success'",
          workingDirectory: package,
        ));
      }
    }

    return _githubJobYaml(
      jobName(
        packages,
        includeOs: oneOs,
        includeSdk: oneSdk,
        includePackage: onePackage,
        includeStage: true,
      ),
      _githubJobOs,
      job.flavor,
      job.sdk,
      commandEntries,
      additionalCacheKeys: {
        'packages': packages.join('-'),
        'commands': commands.join('-'),
      },
    );
  }

  String _commandForOs(String command) {
    if (job.os == 'windows') {
      final split = command.split(' ');
      if (const ['dartfmt', 'pub', 'dartanalyzer'].contains(split.first)) {
        split[0] = '${split[0]}.bat';
        command = split.join(' ');
      }
    }
    return command;
  }
}

/// Returns the content of a Github Action Job.
///
/// See https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-syntax-for-github-actions#jobs
///
/// [jobName] is displayed on GitHUb.
/// See https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-syntax-for-github-actions#jobsjob_idname
///
/// [runsOn] corresponds to the type of machine to run the job on.
/// See https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-syntax-for-github-actions#jobsjob_idruns-on
///
/// [sdkVersion] specifies which version of Dart/Flutter to install.
///
/// [runCommands] specifies the steps to be run.
/// See https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-syntax-for-github-actions#jobsjob_idsteps
///
/// [additionalCacheKeys] is used to create a unique key used to store and
/// retrieve the cache.
Map<String, dynamic> _githubJobYaml(
  String jobName,
  String runsOn,
  PackageFlavor packageFlavor,
  String sdkVersion,
  List<_CommandEntry> runCommands, {
  Map<String, String>? additionalCacheKeys,
}) =>
    {
      'name': jobName,
      'runs-on': runsOn,
      'steps': [
        if (!runsOn.startsWith('windows'))
          _cacheEntries(
            runsOn,
            additionalCacheKeys: {
              'sdk': sdkVersion,
              if (additionalCacheKeys != null) ...additionalCacheKeys,
            },
          ),
        packageFlavor.configurationMap(sdkVersion),
        {
          'id': 'checkout',
          'uses': 'actions/checkout@v3.0.0',
        },
        for (var command in runCommands) command.runContent,
      ],
    };

class _CommandEntry {
  final String name;
  final String run;
  final String? id;
  final String? ifCondition;
  final String? workingDirectory;

  _CommandEntry(
    this.name,
    this.run, {
    this.id,
    this.ifCondition,
    this.workingDirectory,
  });

  /// The entry in the GitHub Action stage representing this object.
  ///
  /// See https://docs.github.com/en/free-pro-team@latest/actions/reference/workflow-syntax-for-github-actions#jobsjob_idsteps
  Map<String, dynamic> get runContent => {
        if (id != null) 'id': id,
        'name': name,
        if (ifCondition != null) 'if': ifCondition,
        if (workingDirectory != null) 'working-directory': workingDirectory,
        'run': run,
      };
}

/// Creates a "step" for enabling caching for the containing job.
///
/// See https://github.com/marketplace/actions/cache
///
/// [runsOn] and [additionalCacheKeys] are used to create a unique key used to
/// store and retrieve the cache.
Map<String, dynamic> _cacheEntries(
  String runsOn, {
  Map<String, String>? additionalCacheKeys,
}) {
  final cacheKeyParts = [
    'os:$runsOn',
    'pub-cache-hosted',
    if (additionalCacheKeys != null) ...[
      for (var entry in additionalCacheKeys.entries)
        '${entry.key}:${entry.value}'
    ]
  ];

  final restoreKeys = [
    for (var i = cacheKeyParts.length; i > 0; i--)
      _maxLength(cacheKeyParts.take(i).join(';'))
  ];

  // Just caching the `hosted` directory because caching git dependencies or
  // activated packages can cause problems.
  const pubCacheHosted = '~/.pub-cache/hosted';

  return {
    'name': 'Cache Pub hosted dependencies',
    'uses': 'actions/cache@v3',
    'with': {
      'path': pubCacheHosted,
      'key': restoreKeys.first,
      'restore-keys': restoreKeys.skip(1).join('\n'),
    }
  };
}

String _maxLength(String input) {
  if (input.length <= 512) return input;
  final hash = ['-!!too_long!!', input.length, input.hashCode].join('-');

  return input.substring(0, 512 - hash.length) + hash;
}

Map<String, dynamic> _selfValidateTaskConfig() => _githubJobYaml(
      selfValidateJobName,
      _ubuntuLatest,
      PackageFlavor.dart,
      'stable',
      [
        for (var command in selfValidateCommands)
          _CommandEntry(selfValidateJobName, command),
      ],
    );

const _ubuntuLatest = 'ubuntu-latest';

/// Used as a place-holder so we can treat all jobs the same in certain
/// workflows.
class _SelfValidateJob implements HasStageName {
  @override
  final String stageName;

  _SelfValidateJob(this.stageName);
}

class _MapEntryWithStage implements MapEntry<String, Map<String, dynamic>> {
  @override
  final String key;
  @override
  final Map<String, dynamic> value;

  final String stageName;

  _MapEntryWithStage(this.key, this.value, this.stageName);
}
