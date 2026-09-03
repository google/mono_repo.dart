// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

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
    '$githubWorkflowDirectory/$filename.yaml';

Map<String, String> generateGitHubYml(RootConfig rootConfig) {
  final output = <String, String>{};

  final orderedStages = calculateOrderedStages(
    rootConfig,
    rootConfig.monoConfig.githubConditionalStages,
  )..add(_onCompletionStage);

  final selfValidateStage = rootConfig.monoConfig.selfValidateStage;
  final allModernJobs = [
    ...rootConfig.expand((p) => p.jobs),
    if (selfValidateStage != null) _SelfValidateJob(selfValidateStage),
  ];

  final commandsToKeys = extractCommands(allModernJobs);

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
      commandsToKeys,
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
        if (entry.key == 'schedule') continue;
        final value = entry.value;
        if (value is Map) {
          on[entry.key] = {...value, 'paths': paths};
        } else if (value is List) {
          on[entry.key] = {'branches': value, 'paths': paths};
        } else if (value is String) {
          on[entry.key] = {
            'branches': [value],
            'paths': paths,
          };
        } else if (value == null) {
          on[entry.key] = {'paths': paths};
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

  final packageMap = {for (var p in rootConfig) p.pubspec.name: p};

  Iterable<PackageConfig> transitiveDeps(PackageConfig config) {
    final deps = <PackageConfig>{};
    final queue = Queue<PackageConfig>()..add(config);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final depNames = [
        ...current.pubspec.dependencies.keys,
        if (current == config) ...current.pubspec.devDependencies.keys,
      ];
      for (var depName in depNames) {
        final depConfig = packageMap[depName];
        if (depConfig != null && deps.add(depConfig)) {
          queue.add(depConfig);
        }
      }
    }
    return deps;
  }

  for (var packageConfig in rootConfig) {
    final posixPath = p.posix.joinAll(p.split(packageConfig.relativePath));
    if (rootConfig.monoConfig.ignore.contains(posixPath)) {
      continue;
    }
    final fileName = posixPath == '.'
        ? packageConfig.pubspec.name
        : posixPath.replaceAll('/', '_');
    final tDeps = transitiveDeps(packageConfig);
    populateJobs(
      fileName,
      'package:${packageConfig.pubspec.name}',
      packageConfig.jobs,
      paths: [
        githubWorkflowFilePath(fileName),
        if (posixPath == '.') ...[
          '**',
          for (var pkg in rootConfig)
            if (pkg.relativePath != '.')
              '!${p.posix.joinAll(p.split(pkg.relativePath))}/**',
        ] else
          '$posixPath/**',
        for (var dep in tDeps)
          '${p.posix.joinAll(p.split(dep.relativePath))}/**',
      ],
    );
  }

  if (selfValidateStage != null) {
    populateJobs('mono_repo_self_validate', 'mono_repo self validate', [
      _SelfValidateJob(selfValidateStage),
    ]);
  }

  if (output.isNotEmpty) {
    output['.github/actions/setup-dart/action.yml'] =
        '''
$createdWith
name: "Setup Dart Package"
description: "Setup Dart SDK, cache pub dependencies, checkout repository, and run pub action."
inputs:
  sdk:
    description: "Dart SDK version or channel"
    required: false
    default: "stable"
  working-directory:
    description: "Working directory for pub command"
    required: false
    default: "."
  pub-action:
    description: "Pub action to run (upgrade or get)"
    required: false
    default: "upgrade"

runs:
  using: "composite"
  steps:
    - name: "Cache Pub hosted dependencies"
      uses: "actions/cache@${ActionInfo.cache.version}"
      with:
        path: "~/.pub-cache/hosted"
        key: "os:\${{ runner.os }};pub-cache-hosted;sdk:\${{ inputs.sdk }};pkg:\${{ inputs.working-directory }}"
        restore-keys: |-
          os:\${{ runner.os }};pub-cache-hosted;sdk:\${{ inputs.sdk }}
          os:\${{ runner.os }};pub-cache-hosted
    - name: "Setup Dart SDK"
      uses: "dart-lang/setup-dart@${ActionInfo.setupDart.version}"
      with:
        sdk: "\${{ inputs.sdk }}"
    - id: "pub_action"
      name: "dart pub \${{ inputs.pub-action }}"
      run: "dart pub \${{ inputs.pub-action }}"
      shell: "bash"
      working-directory: "\${{ inputs.working-directory }}"
''';
    output['.github/actions/setup-flutter/action.yml'] =
        '''
$createdWith
name: "Setup Flutter Package"
description: "Setup Flutter SDK, cache pub dependencies, and run flutter pub action."
inputs:
  channel:
    description: "Flutter SDK channel or version"
    required: false
    default: "stable"
  working-directory:
    description: "Working directory for pub command"
    required: false
    default: "."
  pub-action:
    description: "Pub action to run (upgrade or get)"
    required: false
    default: "upgrade"

runs:
  using: "composite"
  steps:
    - name: "Cache Pub hosted dependencies"
      uses: "actions/cache@${ActionInfo.cache.version}"
      with:
        path: "~/.pub-cache/hosted"
        key: "os:\${{ runner.os }};pub-cache-hosted;channel:\${{ inputs.channel }};pkg:\${{ inputs.working-directory }}"
        restore-keys: |-
          os:\${{ runner.os }};pub-cache-hosted;channel:\${{ inputs.channel }}
          os:\${{ runner.os }};pub-cache-hosted
    - name: "Setup Flutter SDK"
      uses: "subosito/flutter-action@${ActionInfo.setupFlutter.version}"
      with:
        channel: "\${{ inputs.channel }}"
    - id: "pub_action"
      name: "flutter pub \${{ inputs.pub-action }}"
      run: "flutter pub \${{ inputs.pub-action }}"
      shell: "bash"
      working-directory: "\${{ inputs.working-directory }}"
''';
  }

  return output;
}

/// Lists all the jobs, setting their stage, environment, and script.
Iterable<_MapEntryWithStage> _listJobs(
  RootConfig rootConfig,
  List<HasStageName> jobs,
  List<Job>? onCompletionJobs,
  Map<String, ConditionalStage> conditionalStages,
  Map<String, String> commandsToKeys,
) sync* {
  var count = 0;
  final packageConfigByPath = {for (var p in rootConfig) p.relativePath: p};

  String jobName(int jobNum) => 'job_${jobNum.toString().padLeft(3, '0')}';

  _MapEntryWithStage jobEntry(Job content, String stage) {
    final conditional = conditionalStages[stage];
    if (conditional != null) {
      content.ifContent = conditional.ifCondition;
    }
    return _MapEntryWithStage(jobName(++count), content, stage);
  }

  final groupedCIJobs = <_JobGroupKey, List<CIJob>>{};

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
        .map((task) => task.command(ciJob.isNewest))
        .toList();

    final key = _JobGroupKey(
      stageName: ciJob.stageName,
      os: ciJob.os,
      flavor: ciJob.flavor,
      commands: commands,
      description: ciJob.description,
    );

    groupedCIJobs.putIfAbsent(key, () => []).add(ciJob);
  }

  for (var entry in groupedCIJobs.entries) {
    final jobsInGroup = entry.value;

    final firstJob = jobsInGroup.first;
    final commands = firstJob.tasks
        .map((task) => commandsToKeys[task.command(firstJob.isNewest)]!)
        .toList();

    final ciEntry = CIJobEntry(firstJob, commands);

    final job = ciEntry._createJob(
      packageConfigByPath[firstJob.package]!,
      rootConfig,
      oneOs: false,
      oneSdk: false,
      onePackage: true,
      sdks: jobsInGroup.map((j) => j.sdk).toList(),
    );
    yield jobEntry(job, firstJob.stageName);
  }

  // Generate the jobs that run on completion of all other jobs, by adding the
  // appropriate `needs` config to each.
  if (onCompletionJobs != null && onCompletionJobs.isNotEmpty) {
    for (var jobConfig in onCompletionJobs) {
      yield jobEntry(jobConfig, _onCompletionStage);
    }
  }
}

class _JobGroupKey {
  final String stageName;
  final String os;
  final PackageFlavor flavor;
  final List<String> commands;
  final String? description;

  _JobGroupKey({
    required this.stageName,
    required this.os,
    required this.flavor,
    required this.commands,
    this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _JobGroupKey &&
          runtimeType == other.runtimeType &&
          stageName == other.stageName &&
          os == other.os &&
          flavor == other.flavor &&
          const IterableEquality().equals(commands, other.commands) &&
          description == other.description;

  @override
  int get hashCode =>
      stageName.hashCode ^
      os.hashCode ^
      flavor.hashCode ^
      const IterableEquality().hash(commands) ^
      description.hashCode;
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
    PackageConfig packageConfig,
    RootConfig rootConfig, {
    List<String>? packages,
    required bool oneOs,
    required bool oneSdk,
    required bool onePackage,
    List<String>? sdks,
  }) {
    packages ??= [job.package];
    assert(packages.isNotEmpty);
    assert(packages.contains(job.package));
    final pubCommand =
        '${job.flavor.pubCommand} ${rootConfig.monoConfig.pubAction}';

    final commandEntries = <_CommandEntry>[];
    for (var package in packages) {
      final stepNamePrefix = packages.length > 1 ? '$package; ' : '';
      final posixPkg = p.posix.joinAll(p.split(package));
      final safePkg = (posixPkg == '.' || posixPkg.isEmpty)
          ? 'root'
          : posixPkg.replaceAll('/', '_');
      final pubStepId = '${safePkg}_pub_${rootConfig.monoConfig.pubAction}';
      commandEntries.add(
        _CommandEntry(
          '$stepNamePrefix$pubCommand',
          pubCommand,
          id: pubStepId,
          // Run this regardless of the success of other steps other than the
          // pub step.
          ifCondition: "always() && steps.checkout.conclusion == 'success'",
          workingDirectory: package,
        ),
      );
      for (var i = 0; i < commands.length; i++) {
        final command = job.tasks[i].command(job.isNewest);
        if (command.isEmpty || command == 'true') continue;
        commandEntries.add(
          _CommandEntry(
            '$stepNamePrefix$command',
            _commandForOs(command),
            type: job.tasks[i].type,
            workingDirectory: package,
          ),
        );
      }
    }

    final useMatrix = sdks != null && sdks.length > 1;
    final sdkVersion = useMatrix ? r'${{ matrix.sdk }}' : job.sdk;

    return _githubJob(
      jobName(
        packages,
        includeOs: oneOs,
        includeSdk: oneSdk || useMatrix,
        includePackage: onePackage,
        includeStage: true,
      ),
      _githubJobOs,
      job.flavor,
      sdkVersion,
      commandEntries,
      rootConfig,
      config: rootConfig.monoConfig,
      additionalCacheKeys: {
        'packages': packages.join('-'),
        'commands': commands.join('-'),
      },
      strategy: useMatrix
          ? {
              'fail-fast': false,
              'matrix': {'sdk': sdks},
            }
          : null,
      preSteps: packageConfig.preSteps,
      postSteps: packageConfig.postSteps,
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
  Map<String, dynamic>? strategy,
  List<Map>? preSteps,
  List<Map>? postSteps,
}) => Job(
  name: jobName,
  runsOn: runsOn,
  strategy: strategy,
  steps: [
    ActionInfo.checkout.usage(
      id: 'checkout',
      versionOverrides: rootConfig.existingActionVersions,
      withContent: {'persist-credentials': false},
    ),
    () {
      final workingDir = runCommands
          .whereType<_CommandEntry>()
          .firstOrNull
          ?.workingDirectory;
      return Step.uses(
        name: 'Setup ${packageFlavor.name} package',
        uses: './.github/actions/setup-${packageFlavor.name}',
        withContent: {
          packageFlavor == PackageFlavor.flutter ? 'channel' : 'sdk':
              sdkVersion,
          if (workingDir != null && workingDir != '.')
            'working-directory': workingDir,
        },
      );
    }(),
    ..._beforeSteps(runCommands.whereType<_CommandEntry>()),
    if (preSteps != null) ...preSteps.map(Step.fromJson),
    for (var command in runCommands.where(
      (c) => c is! _CommandEntry || c.type != null,
    ))
      ...command.runContent(config, rootConfig),
    if (postSteps != null) ...postSteps.map(Step.fromJson),
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
