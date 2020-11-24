// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

part 'github_config.g.dart';

const defaultGitHubWorkflowFileName = 'dart';
const defaultGitHubWorkflowName = 'Dart CI';

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class GitHubConfig {
  final Map<String, dynamic> env;

  final Map<String, dynamic> on;

  @JsonKey(name: 'on_completion')
  final List<Map<String, dynamic>> onCompletion;

  // TODO: needed until google/json_serializable.dart#747 is fixed
  String get cron => throw UnimplementedError();

  final Map<String, GitHubWorkflow> workflows;

  GitHubConfig(
    this.env,
    Map<String, dynamic> on,
    this.onCompletion,
    String cron,
    this.workflows,
  ) : on = _parseOn(on, cron) {
    if (workflows == null) {
      return;
    }
    _noDefaultFileName();
    _noDuplicateWorkflowNames();
    _noDuplicateStageNames();
  }

  void _noDuplicateStageNames() {
    final stageToWorkflow = <String, String>{};
    for (var entry in workflows.entries) {
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
    for (var name in workflows.values.map((e) => e.name)) {
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
    if (workflows.containsKey(defaultGitHubWorkflowFileName)) {
      throw ArgumentError.value(
        workflows,
        'workflows',
        'Cannot define a workflow with the default key '
            '"$defaultGitHubWorkflowFileName".',
      );
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
      };
}

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class GitHubWorkflow {
  @JsonKey(nullable: false, disallowNullValue: true, required: true)
  final String name;
  @JsonKey(nullable: false, disallowNullValue: true, required: true)
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
    if (stages.any((element) => element == null)) {
      throw ArgumentError.value(
        stages,
        'stages',
        'Stage values cannot be null.',
      );
    }
  }

  factory GitHubWorkflow.fromJson(Map json) => _$GitHubWorkflowFromJson(json);
}

Map<String, dynamic> _parseOn(Map<String, dynamic> on, String cron) {
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
