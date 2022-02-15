// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

void main() {
  test('pub get gets dependencies', () async {
    final process = await TestProcess.start('dart', ['run', 'mono_repo']);

    final output = await process.stdoutStream().join('\n');
    expect(output, _helpOutput);

    await process.shouldExit(0);
  });

  test('readme contains latest task output', () {
    final readme = File('README.md');

    expect(
      readme.readAsStringSync().replaceAll('\r', ''),
      contains('```\n$_helpOutput\n```'),
    );
  });
}

const _helpOutput = r'''
Manage multiple packages in one source repository.

Usage: mono_repo <command> [arguments]

Global options:
-h, --help              Print this usage information.
    --version           Prints the version of mono_repo.
    --[no-]recursive    Whether to recursively walk sub-directories looking for packages.
                        (defaults to on)

Available commands:
  check       Check the state of the repository.
  generate    Generates the CI configuration for child packages.
  presubmit   Run the CI presubmits locally.
  pub         Runs the `pub` command with the provided arguments across all packages.

Run "mono_repo help <command>" for more information about a command.''';
