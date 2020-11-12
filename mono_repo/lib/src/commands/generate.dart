// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ci_shared.dart';
import '../mono_config.dart';

import 'ci_script/generate.dart';
import 'github/generate.dart';
import 'mono_repo_command.dart';
import 'travis/generate.dart';

class GenerateCommand extends MonoRepoCommand {
  @override
  String get name => 'generate';

  @override
  String get description =>
      'Generates the CI configuration for child packages.';

  GenerateCommand() : super() {
    argParser.addFlag(
      'validate',
      negatable: false,
      help: 'Validates that the existing CI config is up to date with '
          'the current configuration. Does not write any files.',
    );
  }

  @override
  void run() {
    final config = rootConfig();
    logPackages(config);
    final validateOnly = argResults['validate'] as bool;
    generateCIScript(config, validateOnly: validateOnly);
    for (var ci in config.monoConfig.ci) {
      switch (ci) {
        case CI.github:
          generateGitHubActions(config, validateOnly: validateOnly);
          break;
        case CI.travis:
          generateTravisConfig(config, validateOnly: validateOnly);
          break;
      }
    }
  }
}
