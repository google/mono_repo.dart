// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

part 'github_config.g.dart';

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class GitHubConfig {
  final Map<String, dynamic> on;

  // TODO: needed until google/json_serializable.dart#747 is fixed
  String get cron => throw UnimplementedError();

  final Map<String, GitHubWorkflow> workflows;

  GitHubConfig(
    Map<String, dynamic> on,
    String cron,
    this.workflows,
  ) : on = _parseOn(on, cron);

  factory GitHubConfig.fromJson(Map json) => _$GitHubConfigFromJson(json);

  Map<String, dynamic> generate(String workflowName) => {
        'name': workflowName,
        if (on != null) 'on': on,
        'defaults': {
          'run': {'shell': 'bash'}
        },
        'env': {'PUB_ENVIRONMENT': 'bot.github'},
      };
}

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class GitHubWorkflow {
  @JsonKey(nullable: false)
  final String name;
  @JsonKey(nullable: false)
  final Set<String> stages;

  GitHubWorkflow(this.name, this.stages) {
    if (stages.isEmpty) {
      throw ArgumentError.value(stages, 'stages', 'cannot be empty');
    }
  }

  factory GitHubWorkflow.fromJson(Map<String, dynamic> json) =>
      _$GitHubWorkflowFromJson(json);
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
