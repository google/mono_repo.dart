// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../ci_shared.dart';
import '../ci_test_script.dart';
import '../mono_config.dart';
import '../root_config.dart';
import '../user_exception.dart';
import 'mono_repo_command.dart';
import 'travis/travis_yaml.dart';

const travisFileName = '.travis.yml';
const travisShPath = 'tool/travis.sh';

class TravisCommand extends MonoRepoCommand {
  @override
  String get name => 'travis';

  @override
  String get description =>
      '(Deprecated, use `generate`) Configure Travis-CI for child packages.';

  TravisCommand() : super() {
    argParser.addFlag('validate',
        negatable: false,
        help: 'Validates that the existing travis config is up to date with '
            'the current configuration. Does not write any files.');
  }

  @override
  void run() {
    print(yellow.wrap(
        'This command is deprecated, use the `generate` command instead.'));
    return generateTravisConfig(
      rootConfig(),
      validateOnly: argResults['validate'] as bool,
    );
  }
}

void generateTravisConfig(
  RootConfig rootConfig, {
  bool validateOnly = false,
}) {
  _checkCIConfig(rootConfig);
  validateOnly ??= false;
  final travisConfig = _GeneratedTravisConfig.generate(
    rootConfig,
  );
  if (validateOnly) {
    _validateFile(
      rootConfig.rootDirectory,
      travisConfig.travisYml,
      travisFileName,
    );
    _validateFile(
      rootConfig.rootDirectory,
      travisConfig.travisSh,
      travisShPath,
    );
  } else {
    writeFile(
      rootConfig.rootDirectory,
      travisFileName,
      travisConfig.travisYml,
      isScript: false,
    );
    writeFile(
      rootConfig.rootDirectory,
      travisShPath,
      travisConfig.travisSh,
      isScript: true,
    );
  }
}

/// The generated yaml and shell script content for travis.
class _GeneratedTravisConfig {
  final String travisYml;
  final String travisSh;

  _GeneratedTravisConfig._(this.travisYml, this.travisSh);

  factory _GeneratedTravisConfig.generate(RootConfig rootConfig) {
    logPackages(rootConfig);
    final commandsToKeys = extractCommands(rootConfig);

    final yml = generateTravisYml(rootConfig, commandsToKeys);

    final sh = generateTestScript(
      commandsToKeys,
      rootConfig.monoConfig.prettyAnsi,
      rootConfig.monoConfig.pubAction,
    );

    return _GeneratedTravisConfig._(yml, sh);
  }
}

/// Thrown if generated config does not match existing config when running with
/// the `--validate` option.
class TravisConfigOutOfDateException extends UserException {
  TravisConfigOutOfDateException()
      : super(
          'Generated travis config is out of date',
          details: 'Rerun `mono_repo travis` to update generated config',
        );
}

/// Checks [expectedPath] versus the content in [expectedContent].
///
/// Throws a [TravisConfigOutOfDateException] if they do not match.
void _validateFile(
  String rootDirectory,
  String expectedContent,
  String expectedPath,
) {
  final shFile = File(p.join(rootDirectory, expectedPath));
  if (!shFile.existsSync() || shFile.readAsStringSync() != expectedContent) {
    throw TravisConfigOutOfDateException();
  }
}

/// Thrown if generated config does not match existing config when running with
/// the `--validate` option.
class CIConfigMismatchException extends UserException {
  CIConfigMismatchException(List<CI> rootCIConfig)
      : super(
          'This command can only be used if your mono_repo.yml config '
          'does not configure other CI providers. Use the `generate` command '
          'instead.',
          details: 'Existing CI config was $rootCIConfig',
        );
}

/// Checks that the root CI config includes exactly one provider, travis.
void _checkCIConfig(RootConfig rootConfig) {
  if (rootConfig.monoConfig.ci != [CI.travis]) {
    throw CIConfigMismatchException(rootConfig.monoConfig.ci);
  }
}
