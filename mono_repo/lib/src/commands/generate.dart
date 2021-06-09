// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../ci_shared.dart';
import '../root_config.dart';
import 'ci_script/generate.dart';
import 'github/generate.dart';
import 'mono_repo_command.dart';

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
  void run() => generate(rootConfig(), argResults!['validate'] as bool);
}

void generate(
  RootConfig config,
  bool validateOnly, {
  bool forceGitHub = false,
}) {
  logPackages(config);
  validateRootConfig(config);
  generateGitHubActions(config, validateOnly: validateOnly);
  // Generate in all cases, since this is used by `presumbit`
  generateCIScript(config, validateOnly: validateOnly);
}
