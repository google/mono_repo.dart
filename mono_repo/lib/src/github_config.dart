// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import 'commands/github/job.dart';

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

/// Extra configuration for customizing the GitHub action context in which a
/// task runs.
class ActionConfig {
  ActionConfig({
    this.id,
    this.uses,
    this.condition,
    this.inputs,
    this.workingDirectory,
    this.shell,
  });

  /// The step's identifier, which can be used to refer to the step and its
  /// outputs in the [condition] property of this and other steps.
  final String? id;

  /// The GitHub action identifier, e.g. `actions/checkout@v3`.
  final String? uses;

  /// The inputs to the action.
  ///
  /// A map of key-value pairs which are passed to the action's `with`
  /// parameter.
  final Map<String, String>? inputs;

  /// The condition on which to run this action.
  final String? condition;

  /// The directory in which to run this action.
  final String? workingDirectory;

  /// The shell override for this action.
  final String? shell;

  factory ActionConfig.fromJson(Map json) {
    // Create a copy of unmodifiable `json`.
    json = Map.of(json);

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
    final Object? inputs = json.remove('with');
    if (inputs is! Map?) {
      throw CheckedFromJsonException(
        json,
        'with',
        'ActionConfig',
        'Invalid `with` parameter. See GitHub docs for more info: '
            'https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepswith',
      );
    }
    // Transform <String, Object> -> <String, String> instead of throwing so
    // that, for example, numerical values are properly converted.
    final mappedInputs = inputs?.map(
      (key, value) {
        if (value is! String) {
          value = jsonEncode(value);
        }
        return MapEntry(key as String, value);
      },
    );
    final Object? condition = json.remove('if');
    if (condition is! String?) {
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
    if (json.isNotEmpty) {
      throw CheckedFromJsonException(
        json,
        json.keys.join(','),
        'ActionConfig',
        'Invalid keys',
      );
    }
    return ActionConfig(
      id: id,
      uses: uses,
      inputs: mappedInputs,
      condition: condition,
      workingDirectory: workingDirectory,
      shell: shell,
    );
  }

  Map<String, Object> toJson() => {
        if (id != null) 'id': id!,
        if (uses != null) 'uses': uses!,
        if (inputs != null) 'with': inputs!,
        if (condition != null) 'if': condition!,
        if (workingDirectory != null) 'working-directory': workingDirectory!,
        if (shell != null) 'shell': shell!,
      };
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
