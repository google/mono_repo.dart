// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../ci_shared.dart';
import '../../ci_test_script.dart';
import '../../root_config.dart';
import '../../user_exception.dart';
import '../travis/generate.dart' show travisShPath;
import 'github_yaml.dart';

const githubActionYamlPath = '.github/workflows/dart.yml';

void generateGitHubActions(
  RootConfig rootConfig, {
  bool validateOnly = false,
}) {
  validateOnly ??= false;
  final githubConfig = _GeneratedGitHubConfig.generate(
    rootConfig,
  );
  if (validateOnly) {
    _validateFile(
      rootConfig.rootDirectory,
      githubConfig.workflowYaml,
      githubActionYamlPath,
    );
    _validateFile(
      rootConfig.rootDirectory,
      githubConfig.travisSh,
      travisShPath,
    );
  } else {
    writeFile(
      rootConfig.rootDirectory,
      githubActionYamlPath,
      githubConfig.workflowYaml,
      isScript: false,
    );
    writeFile(
      rootConfig.rootDirectory,
      travisShPath,
      githubConfig.travisSh,
      isScript: true,
    );
  }
}

/// The generated yaml and shell script content for github.
class _GeneratedGitHubConfig {
  final String workflowYaml;
  final String travisSh;

  _GeneratedGitHubConfig._(this.workflowYaml, this.travisSh);

  factory _GeneratedGitHubConfig.generate(RootConfig rootConfig) {
    logPackages(rootConfig);
    final commandsToKeys = extractCommands(rootConfig);

    final yml = generateGitHubYml(rootConfig, commandsToKeys);

    final sh = generateTestScript(
      commandsToKeys,
      rootConfig.monoConfig.prettyAnsi,
      rootConfig.monoConfig.pubAction,
    );

    return _GeneratedGitHubConfig._(yml, sh);
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
