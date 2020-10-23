// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../ci_shared.dart';
import '../package_config.dart';
import '../root_config.dart';
import '../travis_shell.dart';
import '../user_exception.dart';
import 'mono_repo_command.dart';
import 'travis/travis_yaml.dart';

const travisFileName = '.travis.yml';
const travisShPath = 'tool/travis.sh';

class TravisCommand extends MonoRepoCommand {
  @override
  String get name => 'travis';

  @override
  String get description => 'Configure Travis-CI for child packages.';

  TravisCommand() : super() {
    argParser.addFlag('validate',
        negatable: false,
        help: 'Validates that the existing travis config is up to date with '
            'the current configuration. Does not write any files.');
  }

  @override
  void run() => generateTravisConfig(
        rootConfig(),
        validateOnly: argResults['validate'] as bool,
      );
}

void generateTravisConfig(
  RootConfig rootConfig, {
  bool validateOnly = false,
}) {
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
    _logPkgs(rootConfig);

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

void _logPkgs(Iterable<PackageConfig> configs) {
  for (var pkg in configs) {
    print(styleBold.wrap('package:${pkg.relativePath}'));
    if (pkg.sdks != null && !pkg.dartSdkConfigUsed) {
      print(
        yellow.wrap(
          '  `dart` values (${pkg.sdks.join(', ')}) are not used '
          'and can be removed.',
        ),
      );
    }
    if (pkg.oses != null && !pkg.osConfigUsed) {
      print(
        yellow.wrap(
          '  `os` values (${pkg.oses.join(', ')}) are not used '
          'and can be removed.',
        ),
      );
    }
  }
}
