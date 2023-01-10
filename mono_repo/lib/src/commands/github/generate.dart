// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../ci_shared.dart';
import '../../root_config.dart';
import '../../user_exception.dart';
import 'github_yaml.dart';

void generateGitHubActions(
  RootConfig rootConfig, {
  bool validateOnly = false,
}) {
  final githubConfig = _GeneratedGitHubConfig.generate(
    rootConfig,
  );
  final dependabotConfig = _GeneratedDependabotConfig.generate(
    rootConfig,
  );
  for (var entry in [
    ...githubConfig.workflowFiles.entries,
    ...dependabotConfig.workflowFiles.entries,
  ]) {
    if (validateOnly) {
      _validateFile(
        rootConfig.rootDirectory,
        entry.value,
        entry.key,
      );
    } else {
      writeFile(
        rootConfig.rootDirectory,
        entry.key,
        entry.value,
        isScript: false,
      );
    }
  }
}

/// The generated configuration for dependabot.
class _GeneratedDependabotConfig {
  final Map<String, String> workflowFiles;

  _GeneratedDependabotConfig._(this.workflowFiles);

  factory _GeneratedDependabotConfig.generate(RootConfig rootConfig) {
    final result = <String, String>{};
    final dependabotConfig = rootConfig.monoConfig.github.dependabot;
    if (dependabotConfig != null) {
      final config = {
        'version': 2,
        ...dependabotConfig,
      };
      final packageUpdates = rootConfig.map(
        (packageConfig) => {
          'package-ecosystem': 'pub',
          'directory': packageConfig.relativePath,
          'schedule': {'interval': 'weekly'},
          // TODO(sigurdm): package customizability?
        },
      );

      config['updates'] = [
        ...config['updates'] ?? <dynamic>[],
        ...packageUpdates
      ];
      result['.github/dependabot.yml'] = '''
$createdWith
${const JsonEncoder.withIndent('  ').convert(config)}
''';
    }

    return _GeneratedDependabotConfig._(result);
  }
}

/// The generated yaml and shell script content for github.
class _GeneratedGitHubConfig {
  final Map<String, String> workflowFiles;

  _GeneratedGitHubConfig._(this.workflowFiles);

  factory _GeneratedGitHubConfig.generate(RootConfig rootConfig) {
    final result = generateGitHubYml(rootConfig);
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
