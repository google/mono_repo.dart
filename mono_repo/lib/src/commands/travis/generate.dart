// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../ci_shared.dart';
import '../../root_config.dart';
import '../../user_exception.dart';
import 'travis_yaml.dart';

const travisFileName = '.travis.yml';

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
  } else {
    writeFile(
      rootConfig.rootDirectory,
      travisFileName,
      travisConfig.travisYml,
      isScript: false,
    );
  }
}

/// The generated yaml and shell script content for travis.
class _GeneratedTravisConfig {
  final String travisYml;

  _GeneratedTravisConfig._(this.travisYml);

  factory _GeneratedTravisConfig.generate(RootConfig rootConfig) {
    final commandsToKeys = extractCommands(rootConfig);

    final yml = generateTravisYml(rootConfig, commandsToKeys);

    return _GeneratedTravisConfig._(yml);
  }
}

/// Thrown if generated config does not match existing config when running with
/// the `--validate` option.
class TravisConfigOutOfDateException extends UserException {
  TravisConfigOutOfDateException()
      : super(
          'Generated travis config is out of date',
          details: 'Rerun `mono_repo generate` to update generated config',
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
