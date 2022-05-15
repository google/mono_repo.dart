// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import 'commands/github/job.dart';
import 'commands/github/overrides.dart';

part 'github_config.g.dart';

const defaultGitHubWorkflowFileName = 'dart';
const defaultGitHubWorkflowName = 'Dart CI';

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class GitHubConfig {
  final Map<String, dynamic>? env;

  final Map<String, dynamic>? on;

  @JsonKey(name: 'on_completion')
  final List<Job>? onCompletion;

  // TODO: needed until google/json_serializable.dart#747 is fixed
  String get cron => throw UnimplementedError();

  // Either Strings or Maps are supported here.
  final List<dynamic>? stages;

  final Map<String, GitHubWorkflow>? workflows;

  GitHubConfig(
    this.env,
    Map<String, dynamic>? on,
    this.onCompletion,
    String? cron,
    this.stages,
    this.workflows,
  ) : on = _parseOn(on, cron) {
    if (workflows != null) {
      _noDefaultFileName();
      _noDuplicateWorkflowNames();
      _noDuplicateStageNames();
    }
    _noOnCompletionNeedsConfig();
  }

  void _noDuplicateStageNames() {
    final stageToWorkflow = <String, String>{};
    for (var entry in workflows!.entries) {
      for (var stage in entry.value.stages) {
        final existing = stageToWorkflow[stage];
        if (existing != null) {
          throw ArgumentError.value(
            workflows,
            'workflows',
            'Stage "$stage" is already defined in workflow "$existing".',
          );
        }
        stageToWorkflow[stage] = entry.key;
      }
    }
  }

  void _noDuplicateWorkflowNames() {
    final nameCounts = <String, int>{};
    for (var name in workflows!.values.map((e) => e.name)) {
      nameCounts[name] = (nameCounts[name] ?? 0) + 1;
    }
    final moreThanOne = nameCounts.entries
        .where((element) => element.value > 1)
        .map((e) => e.key)
        .toList();
    if (moreThanOne.isNotEmpty) {
      throw ArgumentError.value(
        workflows,
        'workflows',
        'Workflows must have different names. '
            'Duplicate name(s): ${moreThanOne.join(', ')}',
      );
    }
  }

  void _noDefaultFileName() {
    if (workflows!.containsKey(defaultGitHubWorkflowFileName)) {
      throw ArgumentError.value(
        workflows,
        'workflows',
        'Cannot define a workflow with the default key '
            '"$defaultGitHubWorkflowFileName".',
      );
    }
  }

  void _noOnCompletionNeedsConfig() {
    if (onCompletion == null) return;
    for (var jobConfig in onCompletion!) {
      if (jobConfig.needs != null) {
        throw ArgumentError.value(
            jobConfig,
            'on_completion',
            'Cannot define a `needs` key for `on_completion` jobs, this is '
                'filled in for you to depend on all jobs.');
      }
    }
  }

  factory GitHubConfig.fromJson(Map json) => _$GitHubConfigFromJson(json);

  Map<String, dynamic> generate(String workflowName) => {
        'name': workflowName,
        if (on != null) 'on': on,
        'defaults': {
          'run': {'shell': 'bash'}
        },
        'env': {'PUB_ENVIRONMENT': 'bot.github', ...?env},
        // Declare default permissions as read only.
        'permissions': 'read-all'
      };
}

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class GitHubWorkflow {
  @JsonKey(disallowNullValue: true, required: true)
  final String name;
  @JsonKey(disallowNullValue: true, required: true)
  final Set<String> stages;

  GitHubWorkflow(this.name, this.stages) {
    if (name == defaultGitHubWorkflowName) {
      throw ArgumentError.value(
        name,
        'name',
        'Cannot be the default workflow name "$defaultGitHubWorkflowName".',
      );
    }
    if (stages.isEmpty) {
      throw ArgumentError.value(stages, 'stages', 'Cannot be empty.');
    }
  }

  factory GitHubWorkflow.fromJson(Map json) => _$GitHubWorkflowFromJson(json);
}

/// Configuration for a single step in a GitHub Actions task.
class GitHubActionConfig implements GitHubActionOverrides {
  GitHubActionConfig({
    this.id,
    this.name,
    this.run,
    this.uses,
    this.ifContent,
    this.withContent,
    this.workingDirectory,
    this.shell,
    this.env,
    this.continueOnError,
    this.timeoutMinutes,
    this.otherConfig,
  }) : assert(
          run != null || uses != null,
          'Either `run` or `uses` must be specified',
        );

  @override
  final String? id;

  @override
  final String? name;

  @override
  final String? run;

  @override
  final String? uses;

  /// The command identifier for this step, used in caching.
  String get command => (run ?? uses)!;

  @override
  final Map<String, dynamic>? withContent;

  @override
  final String? ifContent;

  @override
  final String? workingDirectory;

  @override
  final String? shell;

  @override
  final Map<String, String>? env;

  @override
  final bool? continueOnError;

  @override
  final int? timeoutMinutes;

  /// Configuration options not defined by one of the other keys.
  final Map<String, dynamic>? otherConfig;

  factory GitHubActionConfig.fromJson(Map json) {
    // Create a copy of unmodifiable `json`.
    json = Map.of(json);

    // Transform <String, Object> -> <String, String> instead of throwing so
    // that, for example, numerical values are properly converted.
    Map<String, String>? toEnvMap(Map? map) => map?.map(
          (key, value) {
            if (value is! String) {
              value = jsonEncode(value);
            }
            return MapEntry(key as String, value);
          },
        );

    final Object? id = json.remove('id');
    if (id is! String?) {
      throw CheckedFromJsonException(
        json,
        'id',
        'ActionConfig',
        'Invalid `id` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsid',
      );
    }
    final Object? name = json.remove('name');
    if (name is! String?) {
      throw CheckedFromJsonException(
        json,
        'name',
        'ActionConfig',
        'Invalid `name` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsname',
      );
    }
    final Object? run = json.remove('run');
    if (run is! String?) {
      throw CheckedFromJsonException(
        json,
        'run',
        'ActionConfig',
        'Invalid `run` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsrun',
      );
    }
    final Object? uses = json.remove('uses');
    if (uses is! String?) {
      throw CheckedFromJsonException(
        json,
        'uses',
        'ActionConfig',
        'Invalid `uses` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsuses',
      );
    }
    final Object? withContent = json.remove('with');
    if (withContent is! Map?) {
      throw CheckedFromJsonException(
        json,
        'with',
        'ActionConfig',
        'Invalid `with` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepswith',
      );
    }
    final Object? ifContent = json.remove('if');
    if (ifContent is! String?) {
      throw CheckedFromJsonException(
        json,
        'if',
        'ActionConfig',
        'Invalid `if` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsif',
      );
    }
    final Object? workingDirectory = json.remove('working-directory');
    if (workingDirectory is! String?) {
      throw CheckedFromJsonException(
        json,
        'working-directory',
        'ActionConfig',
        'Invalid `working-directory` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsrun',
      );
    }
    final Object? shell = json.remove('shell');
    if (shell is! String?) {
      throw CheckedFromJsonException(
        json,
        'shell',
        'ActionConfig',
        'Invalid `shell` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsshell',
      );
    }
    final Object? env = json.remove('env');
    if (env is! Map?) {
      throw CheckedFromJsonException(
        json,
        'env',
        'ActionConfig',
        'Invalid `env` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepsenv',
      );
    }
    final Object? continueOnError = json.remove('continue-on-error');
    if (continueOnError is! bool?) {
      throw CheckedFromJsonException(
        json,
        'continue-on-error',
        'ActionConfig',
        'Invalid `continue-on-error` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepscontinue-on-error',
      );
    }
    final Object? timeoutMinutes = json.remove('timeout-minutes');
    if (timeoutMinutes is! num?) {
      throw CheckedFromJsonException(
        json,
        'timeout-minutes',
        'ActionConfig',
        'Invalid `timeout-minutes` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepstimeout-minutes',
      );
    }

    if (uses == null && run == null) {
      throw CheckedFromJsonException(
        json,
        'run,uses',
        'ActionConfig',
        'Either `run` or `uses` must be specified',
      );
    }

    return GitHubActionConfig(
      id: id,
      uses: uses,
      run: run,
      withContent: withContent?.cast(),
      ifContent: ifContent,
      workingDirectory: workingDirectory,
      shell: shell,
      env: toEnvMap(env),
      continueOnError: continueOnError,
      timeoutMinutes: timeoutMinutes?.toInt(),
      otherConfig: json.cast(),
    );
  }
}

Map<String, dynamic> _parseOn(Map<String, dynamic>? on, String? cron) {
  if (on == null) {
    if (cron == null) {
      return _defaultOn;
    } else {
      return {
        ..._defaultOn,
        'schedule': [
          {'cron': cron}
        ]
      };
    }
  }

  if (cron != null) {
    throw ArgumentError.value(
      cron,
      'cron',
      'Cannot set `cron` if `on` has a value.',
    );
  }

  return on;
}

const _defaultOn = {
  'push': {
    'branches': [
      'main',
      'master',
    ]
  },
  // A `null` value here means all pull requests are processed by this workflow.
  'pull_request': null,
};
