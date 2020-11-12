// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../ci_shared.dart';
import '../../ci_test_script.dart';
import '../../root_config.dart';
import '../../user_exception.dart';

const ciScriptPath = '.dart_tool/mono_repo/ci.sh';

void generateCIScript(
  RootConfig rootConfig, {
  bool validateOnly = false,
}) {
  validateOnly ??= false;
  final ciScript = _GeneratedCIScript.generate(rootConfig).ciScript;
  if (validateOnly) {
    _validateFile(
      rootConfig.rootDirectory,
      ciScript,
      ciScriptPath,
    );
  } else {
    writeFile(
      rootConfig.rootDirectory,
      ciScriptPath,
      ciScript,
      isScript: true,
    );
  }
}

/// The shared generated shell script content for CI.
class _GeneratedCIScript {
  final String ciScript;

  _GeneratedCIScript._(this.ciScript);

  factory _GeneratedCIScript.generate(RootConfig rootConfig) {
    logPackages(rootConfig);
    final commandsToKeys = extractCommands(rootConfig);

    final script = generateTestScript(
      commandsToKeys,
      rootConfig.monoConfig.prettyAnsi,
      rootConfig.monoConfig.pubAction,
    );

    return _GeneratedCIScript._(script);
  }
}

/// Thrown if generated config does not match existing config when running with
/// the `--validate` option.
class CIScriptOutOfDateException extends UserException {
  CIScriptOutOfDateException()
      : super(
          'Generated ci script is out of date',
          details: 'Rerun `mono_repo generate` to update the generated script',
        );
}

/// Checks [expectedPath] versus the content in [expectedContent].
///
/// Throws a [CIScriptOutOfDateException] if they do not match.
void _validateFile(
  String rootDirectory,
  String expectedContent,
  String expectedPath,
) {
  final shFile = File(p.join(rootDirectory, expectedPath));
  if (!shFile.existsSync() || shFile.readAsStringSync() != expectedContent) {
    throw CIScriptOutOfDateException();
  }
}
