// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import '../../basic_config.dart';
import '../../ci_shared.dart';
import '../../github_config.dart';
import '../../mono_config.dart';
import '../../package_config.dart';
import '../../package_flavor.dart';
import '../../root_config.dart';
import '../../task_type.dart';
import '../../user_exception.dart';
import '../../yaml.dart';
import 'action_info.dart';
import 'job.dart';
import 'step.dart';

const _onCompletionStage = '_on_completion';

Map<String, String> generateGitHubYml(RootConfig rootConfig) {
  final jobs = <HasStageName>[
    ...rootConfig.expand((config) => config.jobs),
  ];

  final selfValidateStage = rootConfig.monoConfig.selfValidateStage;
  if (selfValidateStage != null) {
    jobs.add(_SelfValidateJob(selfValidateStage));
  }

  final allJobStages = {for (var job in jobs) job.stageName};
  final orderedStages = calculateOrderedStages(
    rootConfig,
    rootConfig.monoConfig.githubConditionalStages,
  )..add(_onCompletionStage);

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
      rootConfig.monoConfig.mergeStages,
      rootConfig.monoConfig.github.onCompletion,
      rootConfig.monoConfig.githubConditionalStages,
    ).toList();

    var currStageJobs = <String>{};
    final allPrevStageJobs = <String>{};
    String? currStageName;

    // TaskType : {jobs names}
    final completionMap = SplayTreeMap<ActionInfo, Set<String>>();

    for (var job in allJobs) {
      if (job.stageName != currStageName) {
        currStageName = job.stageName;
        allPrevStageJobs.addAll(currStageJobs);
        currStageJobs = {};
      }
      currStageJobs.add(job.id);
      if (allPrevStageJobs.isNotEmpty) {
        job.value.needs = allPrevStageJobs.toList();
      }

      // process post-run logic
      for (var step in job.value.steps) {
        if (step.hasCompletionJob) {
          completionMap
              .putIfAbsent(step.actionInfo!, SplayTreeSet<String>.new)
              .add(job.id);
        }
      }
    }

    final jobList =
        Map.fromEntries(allJobs.map((e) => MapEntry(e.id, e.value)));

    for (var completion in completionMap.entries) {
      final job = completion.key.completionJobFactory!()
        ..needs = completion.value.toList();

      jobList['job_${jobList.length + 1}'] = job;
    }

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
  Set<String> mergeStages,
  List<Job>? onCompletionJobs,
  Map<String, ConditionalStage> conditionalStages,
) sync* {
  final jobEntries = <CIJobEntry>[];

  var count = 0;

  String jobName(int jobNum) => 'job_${jobNum.toString().padLeft(3, '0')}';

  _MapEntryWithStage jobEntry(Job content, String stage) {
    final conditional = conditionalStages[stage];
    if (conditional != null) {
      content.ifContent = conditional.ifCondition;
    }
    return _MapEntryWithStage(
      jobName(++count),
      content,
      stage,
    );
  }

  for (var job in jobs) {
    if (job is _SelfValidateJob) {
      yield jobEntry(_selfValidateJob(rootConfig.monoConfig), job.stageName);
      continue;
    }

    final ciJob = job as CIJob;

    final commandsToKeys = extractCommands(rootConfig);

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
      final yaml = first._createJob(
        rootConfig,
        packages: packages,
        oneOs: differentOperatingSystems.length == 1,
        oneSdk: differentSdks.length == 1,
        onePackage: differentPackages.length == 1,
      );
      yield jobEntry(yaml, first.job.stageName);
    } else {
      yield* entry.value.map(
        (e) {
          final yaml = e._createJob(
            rootConfig,
            oneOs: differentOperatingSystems.length == 1,
            oneSdk: differentSdks.length == 1,
            onePackage: differentPackages.length == 1,
          );
          return jobEntry(yaml, e.job.stageName);
        },
      );
    }
  }

  // Generate the jobs that run on completion of all other jobs, by adding the
  // appropriate `needs` config to each.
  if (onCompletionJobs != null && onCompletionJobs.isNotEmpty) {
    for (var jobConfig in onCompletionJobs) {
      yield jobEntry(
        jobConfig,
        _onCompletionStage,
      );
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

  Job _createJob(
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
      commandEntries.add(
        _CommandEntry(
          '$package; $pubCommand',
          pubCommand,
          id: pubStepId,
          // Run this regardless of the success of other steps other than the
          // pub step.
          ifCondition: "always() && steps.checkout.conclusion == 'success'",
          workingDirectory: package,
        ),
      );
      for (var i = 0; i < commands.length; i++) {
        commandEntries.add(
          _CommandEntry(
            '$package; ${job.tasks[i].command}',
            _commandForOs(job.tasks[i].command),
            type: job.tasks[i].type,
            // Run this regardless of the success of other steps other than the
            // pub step.
            ifCondition: "always() && steps.$pubStepId.conclusion == 'success'",
            workingDirectory: package,
          ),
        );
      }
    }

    return _githubJob(
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
      config: rootConfig.monoConfig,
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
Job _githubJob(
  String jobName,
  String runsOn,
  PackageFlavor packageFlavor,
  String sdkVersion,
  List<_CommandEntryBase> runCommands, {
  required BasicConfiguration config,
  Map<String, String>? additionalCacheKeys,
}) =>
    Job(
      name: jobName,
      runsOn: runsOn,
      steps: [
        if (!runsOn.startsWith('windows'))
          _cacheEntries(
            runsOn,
            additionalCacheKeys: {
              'sdk': sdkVersion,
              if (additionalCacheKeys != null) ...additionalCacheKeys,
            },
          ),
        packageFlavor.setupStep(sdkVersion),
        ..._beforeSteps(runCommands.whereType<_CommandEntry>()),
        ActionInfo.checkout.usage(
          id: 'checkout',
        ),
        for (var command in runCommands) ...command.runContent(config),
      ],
    );

Set<TaskType> _orderedTypes(Iterable<_CommandEntry> commands) =>
    SplayTreeSet.of(commands.map((e) => e.type).whereType<TaskType>());

Iterable<Step> _beforeSteps(
  Iterable<_CommandEntry> commands,
) sync* {
  for (var type in _orderedTypes(commands)) {
    yield* type.beforeAllSteps;
  }
}

class _CommandEntryBase {
  final String name;
  final String run;

  _CommandEntryBase(this.name, this.run);

  Iterable<Step> runContent(BasicConfiguration config) =>
      [Step.run(name: name, run: run)];
}

class _CommandEntry extends _CommandEntryBase {
  final TaskType? type;
  final String? id;
  final String? ifCondition;
  final String workingDirectory;

  _CommandEntry(
    super.name,
    super.run, {
    required this.workingDirectory,
    this.type,
    this.id,
    this.ifCondition,
  });

  @override
  Iterable<Step> runContent(BasicConfiguration config) => [
        Step.run(
          id: id,
          name: name,
          ifContent: ifCondition,
          workingDirectory: workingDirectory,
          run: run,
        ),
        ...?type?.afterEachSteps(workingDirectory, config),
      ];
}

/// Creates a "step" for enabling caching for the containing job.
///
/// See https://github.com/marketplace/actions/cache
///
/// [runsOn] and [additionalCacheKeys] are used to create a unique key used to
/// store and retrieve the cache.
Step _cacheEntries(
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

  return ActionInfo.cache.usage(
    withContent: {
      'path': pubCacheHosted,
      'key': restoreKeys.first,
      'restore-keys': restoreKeys.skip(1).join('\n'),
    },
  );
}

String _maxLength(String input) {
  if (input.length <= 512) return input;
  final hash = ['-!!too_long!!', input.length, input.hashCode].join('-');

  return input.substring(0, 512 - hash.length) + hash;
}

Job _selfValidateJob(BasicConfiguration config) => _githubJob(
      selfValidateJobName,
      _ubuntuLatest,
      PackageFlavor.dart,
      'stable',
      [
        for (var command in selfValidateCommands)
          _CommandEntryBase(selfValidateJobName, command),
      ],
      config: config,
    );

const _ubuntuLatest = 'ubuntu-latest';

/// Used as a place-holder so we can treat all jobs the same in certain
/// workflows.
class _SelfValidateJob implements HasStageName {
  @override
  final String stageName;

  _SelfValidateJob(this.stageName);
}

class _MapEntryWithStage {
  final String id;
  final Job value;

  final String stageName;

  _MapEntryWithStage(
    this.id,
    this.value,
    this.stageName,
  );
}

extension on PackageFlavor {
  Step setupStep(String sdkVersion) {
    switch (this) {
      case PackageFlavor.dart:
        return ActionInfo.setupDart.usage(
          withContent: {'sdk': sdkVersion},
        );

      case PackageFlavor.flutter:
        return ActionInfo.setupFlutter.usage(
          withContent: {'channel': sdkVersion},
        );
    }
  }
}
