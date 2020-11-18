// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:io/ansi.dart';

import '../ci_shared.dart';
import '../mono_config.dart';
import '../root_config.dart';
import '../user_exception.dart';
import 'ci_script/generate.dart';
import 'mono_repo_command.dart';
import 'travis/generate.dart';

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
    final config = rootConfig();
    _checkCIConfig(config);
    logPackages(config);
    final validateOnly = argResults['validate'] as bool;
    generateTravisConfig(
      config,
      validateOnly: validateOnly,
    );
    generateCIScript(config, validateOnly: validateOnly);
  }
}

/// Thrown if generated config does not match existing config when running with
/// the `--validate` option.
class CIConfigMismatchException extends UserException {
  CIConfigMismatchException(Set<CI> rootCIConfig)
      : super(
          'This command can only be used if your mono_repo.yml config '
          'does not configure other CI providers. Use the `generate` command '
          'instead.',
          details: 'Existing CI config was $rootCIConfig',
        );
}

/// Checks that the root CI config includes exactly one provider, travis.
void _checkCIConfig(RootConfig rootConfig) {
  final ci = rootConfig.monoConfig.ci;

  if (ci.length == 1 && ci.single == CI.travis) {
    return;
  }
  throw CIConfigMismatchException(ci);
}
