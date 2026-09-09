// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;

import 'commands/github/github_yaml.dart';
import 'commands/github/job.dart';
import 'root_config.dart';

part 'github_config.g.dart';

const defaultGitHubWorkflowFileName = 'dart';
const defaultGitHubWorkflowName = 'Dart CI';

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class GitHubConfig {
  final Map<String, dynamic>? env;

  final Map<String, dynamic>? on;

  @JsonKey(name: 'on_completion')
  final List<Job>? onCompletion;

  final Map<String, dynamic>? dependabot;

  final Object? permissions;

  final String? cron;

  // Either Strings or Maps are supported here.
  final List<dynamic>? stages;

  final Map<String, GitHubWorkflow>? workflows;

  GitHubConfig(
    this.env,
    this.on,
    this.onCompletion,
    this.cron,
    this.stages,
    this.workflows,
    this.dependabot, [
    this.permissions,
  ]) {
    if (cron != null && on != null) {
      throw ArgumentError.value(
        cron,
        'cron',
        'Cannot set `cron` if `on` has a value.',
      );
    }
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
              'filled in for you to depend on all jobs.',
        );
      }
    }
  }

  factory GitHubConfig.fromJson(Map json) => _$GitHubConfigFromJson(json);

  Map<String, dynamic> generate(
    String workflowName, {
    RootConfig? rootConfig,
    String? fileName,
  }) => {
    'name': workflowName,
    'on': on ?? _defaultOn(rootConfig: rootConfig, fileName: fileName),
    'defaults': {
      'run': {'shell': 'bash'},
    },
    'env': {'PUB_ENVIRONMENT': 'bot.github', ...?env},
    // Declare default permissions as read only.
    'permissions': permissions ?? 'read-all',
  };

  Map<String, dynamic> _defaultOn({
    RootConfig? rootConfig,
    String? fileName,
  }) {
    final workflowPath = fileName != null
        ? githubWorkflowFilePath(fileName)
        : defaultGitHubWorkflowFilePath;
    final paths = <String>{
      workflowPath,
      'mono_repo.yaml',
    };

    if (rootConfig != null) {
      for (var file in const [
        'analysis_options.yaml',
        'build.yaml',
        'pubspec.lock',
        'pubspec.yaml',
      ]) {
        if (File(p.join(rootConfig.rootDirectory, file)).existsSync()) {
          paths.add(file);
        }
      }
    }

    paths.add('**/mono_pkg.yaml');

    if (rootConfig != null) {
      for (var pkg in rootConfig) {
        final normalized = p.posix.joinAll(p.split(pkg.relativePath));
        paths.add(
          normalized.isEmpty || normalized == '.' ? '**' : '$normalized/**',
        );
      }
    }

    paths.add('!**/*.md');

    final pathList = paths.toList();

    return {
      'push': {
        'branches': ['main', 'master'],
        'paths': pathList,
      },
      'pull_request': {
        'paths': pathList,
      },
      if (cron != null)
        'schedule': [
          {'cron': cron},
        ],
    };
  }
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
