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
import '../../yaml.dart';
import 'action_info.dart';
import 'job.dart';
import 'step.dart';

const _onCompletionStage = '_on_completion';

const githubWorkflowDirectory = '.github/workflows';

final defaultGitHubWorkflowFilePath = githubWorkflowFilePath(
  defaultGitHubWorkflowFileName,
);

String githubWorkflowFilePath(String filename) =>
    '$githubWorkflowDirectory/$filename.yml';

Map<String, String> generateGitHubYml(RootConfig rootConfig) {
  final output = <String, String>{};

  final orderedStages = calculateOrderedStages(
    rootConfig,
    rootConfig.monoConfig.githubConditionalStages,
  )..add(_onCompletionStage);

  void populateJobs(
    String fileName,
    String workflowName,
    Iterable<HasStageName> myJobs, {
    List<String>? paths,
  }) {
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

    final jobList = Map.fromEntries(
      allJobs.map((e) => MapEntry(e.id, e.value)),
    );

    for (var completion in completionMap.entries) {
      final job = completion.key.completionJobFactory!(rootConfig)
        ..needs = completion.value.toList();

      jobList['job_${jobList.length + 1}'] = job;
    }

    final githubConfig = Map<String, dynamic>.from(
      rootConfig.monoConfig.github.generate(workflowName),
    );
    if (paths != null) {
      final on = Map<String, dynamic>.from(githubConfig['on'] as Map);
      githubConfig['on'] = on;
      for (var entry in on.entries) {
        final value = entry.value;
        if (value is Map) {
          on[entry.key] = {...value, 'paths': paths};
        }
      }
    }

    output[githubWorkflowFilePath(fileName)] =
        '''
$createdWith
${toYaml(githubConfig)}

${toYaml({'jobs': jobList})}
''';
  }

  for (var packageConfig in rootConfig) {
    final fileName = packageConfig.relativePath.replaceAll('/', '_');
    populateJobs(
      fileName,
      'package:${packageConfig.pubspec.name}',
      packageConfig.jobs,
      paths: [
        githubWorkflowFilePath(fileName),
        '${packageConfig.relativePath}/**',
      ],
    );
  }

  final selfValidateStage = rootConfig.monoConfig.selfValidateStage;
  if (selfValidateStage != null) {
    populateJobs('mono_repo_self_validate', 'mono_repo self validate', [
      _SelfValidateJob(selfValidateStage),
    ]);
  }

  return output;
}

/// Lists all the jobs, setting their stage, environment, and script.
Iterable<_MapEntryWithStage> _listJobs(
  RootConfig rootConfig,
  List<HasStageName> jobs,
  List<Job>? onCompletionJobs,
  Map<String, ConditionalStage> conditionalStages,
) sync* {
  var count = 0;

  String jobName(int jobNum) => 'job_${jobNum.toString().padLeft(3, '0')}';

  _MapEntryWithStage jobEntry(Job content, String stage) {
    final conditional = conditionalStages[stage];
    if (conditional != null) {
      content.ifContent = conditional.ifCondition;
    }
    return _MapEntryWithStage(jobName(++count), content, stage);
  }

  final commandsToKeys = _extractCommands(jobs);

  for (var job in jobs) {
    if (job is _SelfValidateJob) {
      yield jobEntry(
        _selfValidateJob(rootConfig.monoConfig, rootConfig),
        job.stageName,
      );
      continue;
    }

    final ciJob = job as CIJob;

    final commands = ciJob.tasks
        .map((task) => commandsToKeys[task.command(ciJob.isNewest)]!)
        .toList();

    final entry = CIJobEntry(ciJob, commands);

    final yaml = entry._createJob(
      rootConfig,
      oneOs: false,
      oneSdk: false,
      onePackage: true,
    );
    yield jobEntry(yaml, ciJob.stageName);
  }

  // Generate the jobs that run on completion of all other jobs, by adding the
  // appropriate `needs` config to each.
  if (onCompletionJobs != null && onCompletionJobs.isNotEmpty) {
    for (var jobConfig in onCompletionJobs) {
      yield jobEntry(jobConfig, _onCompletionStage);
    }
  }
}

/// Gives a map of command to unique task key for all [jobs].
Map<String, String> _extractCommands(Iterable<HasStageName> jobs) {
  final commandsToKeys = <String, String>{};

  final tasksToConfigure = jobs
      .whereType<CIJob>()
      .expand((job) => job.tasks.map((task) => (task, job.isNewest)))
      .toList();

  final taskTypes = tasksToConfigure.map((t) => t.$1.type).toSet();

  for (var taskType in taskTypes) {
    final commands = tasksToConfigure
        .where((t) => t.$1.type == taskType)
        .map((t) => t.$1.command(t.$2))
        .toSet();

    if (commands.length == 1) {
      commandsToKeys[commands.single] = taskType.name;
      continue;
    }

    final paddingSize = (commands.length - 1).toString().length;

    var count = 0;
    for (var command in commands) {
      commandsToKeys[command] =
          '${taskType.name}_${count.toString().padLeft(paddingSize, '0')}';
      count++;
    }
  }

  return commandsToKeys;
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
      final pubStepId =
          '${package.replaceAll('/', '_')}_'
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
            '$package; ${job.tasks[i].command(job.isNewest)}',
            _commandForOs(job.tasks[i].command(job.isNewest)),
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
      rootConfig,
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
  List<_CommandEntryBase> runCommands,
  RootConfig rootConfig, {
  required BasicConfiguration config,
  Map<String, String>? additionalCacheKeys,
}) => Job(
  name: jobName,
  runsOn: runsOn,
  steps: [
    if (!runsOn.startsWith('windows'))
      _cacheEntries(
        runsOn,
        rootConfig: rootConfig,
        additionalCacheKeys: {
          'sdk': sdkVersion,
          if (additionalCacheKeys != null) ...additionalCacheKeys,
        },
      ),
    packageFlavor.setupStep(sdkVersion, rootConfig),
    ..._beforeSteps(runCommands.whereType<_CommandEntry>()),
    ActionInfo.checkout.usage(
      id: 'checkout',
      versionOverrides: rootConfig.existingActionVersions,
    ),
    for (var command in runCommands) ...command.runContent(config, rootConfig),
  ],
);

Set<TaskType> _orderedTypes(Iterable<_CommandEntry> commands) =>
    SplayTreeSet.of(commands.map((e) => e.type).whereType<TaskType>());

Iterable<Step> _beforeSteps(Iterable<_CommandEntry> commands) sync* {
  for (var type in _orderedTypes(commands)) {
    yield* type.beforeAllSteps;
  }
}

class _CommandEntryBase {
  final String name;
  final String run;

  _CommandEntryBase(this.name, this.run);

  Iterable<Step> runContent(BasicConfiguration config, RootConfig rootConfig) =>
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
  Iterable<Step> runContent(BasicConfiguration config, RootConfig rootConfig) =>
      [
        Step.run(
          id: id,
          name: name,
          ifContent: ifCondition,
          workingDirectory: workingDirectory,
          run: run,
        ),
        ...?type?.afterEachSteps(workingDirectory, config, rootConfig),
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
  required RootConfig rootConfig,
  Map<String, String>? additionalCacheKeys,
}) {
  final cacheKeyParts = [
    'os:$runsOn',
    'pub-cache-hosted',
    if (additionalCacheKeys != null) ...[
      for (var entry in additionalCacheKeys.entries)
        '${entry.key}:${entry.value}',
    ],
  ];

  final restoreKeys = [
    for (var i = cacheKeyParts.length; i > 0; i--)
      _maxLength(cacheKeyParts.take(i).join(';')),
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
    versionOverrides: rootConfig.existingActionVersions,
  );
}

String _maxLength(String input) {
  if (input.length <= 512) return input;
  final hash = ['-!!too_long!!', input.length, input.hashCode].join('-');

  return input.substring(0, 512 - hash.length) + hash;
}

Job _selfValidateJob(BasicConfiguration config, RootConfig rootConfig) =>
    _githubJob(
      selfValidateJobName,
      _ubuntuLatest,
      PackageFlavor.dart,
      'stable',
      [
        for (var command in selfValidateCommands)
          _CommandEntryBase(selfValidateJobName, command),
      ],
      rootConfig,
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

  _MapEntryWithStage(this.id, this.value, this.stageName);
}

extension on PackageFlavor {
  Step setupStep(String sdkVersion, RootConfig rootConfig) {
    switch (this) {
      case PackageFlavor.dart:
        return ActionInfo.setupDart.usage(
          withContent: {'sdk': sdkVersion},
          versionOverrides: rootConfig.existingActionVersions,
        );

      case PackageFlavor.flutter:
        return ActionInfo.setupFlutter.usage(
          withContent: {'channel': sdkVersion},
          versionOverrides: rootConfig.existingActionVersions,
        );
    }
  }
}
