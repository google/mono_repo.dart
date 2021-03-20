// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../ci_shared.dart';
import '../../github_config.dart';
import '../../root_config.dart';
import '../../user_exception.dart';
import 'github_yaml.dart';

const githubWorkflowDirectory = '.github/workflows';

final defaultGitHubWorkflowFilePath =
    githubWorkflowFilePath(defaultGitHubWorkflowFileName);

String githubWorkflowFilePath(String filename) =>
    '$githubWorkflowDirectory/$filename.yml';

void generateGitHubActions(
  RootConfig rootConfig, {
  bool validateOnly = false,
}) {
  final githubConfig = _GeneratedGitHubConfig.generate(
    rootConfig,
  );
  for (var entry in githubConfig.workflowFiles.entries) {
    if (validateOnly) {
      _validateFile(
        rootConfig.rootDirectory,
        entry.value,
        githubWorkflowFilePath(entry.key),
      );
    } else {
      writeFile(
        rootConfig.rootDirectory,
        githubWorkflowFilePath(entry.key),
        entry.value,
        isScript: false,
      );
    }
  }
}

/// The generated yaml and shell script content for github.
class _GeneratedGitHubConfig {
  final Map<String, String> workflowFiles;

  _GeneratedGitHubConfig._(this.workflowFiles);

  factory _GeneratedGitHubConfig.generate(RootConfig rootConfig) {
    final commandsToKeys = extractCommands(rootConfig);

    final result = generateGitHubYml(rootConfig, commandsToKeys);

    return _GeneratedGitHubConfig._(result);
  }
}

/// Thrown if generated config does not match existing config when running with
/// the `--validate` option.
class GithubConfigOutOfDateException extends UserException {
  GithubConfigOutOfDateException()
      : super(
          'Generated github config is out of date',
          details: 'Rerun `mono_repo generate` to update generated config',
        );
}

/// Checks [expectedPath] versus the content in [expectedContent].
///
/// Throws a [GithubConfigOutOfDateException] if they do not match.
void _validateFile(
  String rootDirectory,
  String expectedContent,
  String expectedPath,
) {
  final shFile = File(p.join(rootDirectory, expectedPath));
  if (!shFile.existsSync() || shFile.readAsStringSync() != expectedContent) {
    throw GithubConfigOutOfDateException();
  }
}
