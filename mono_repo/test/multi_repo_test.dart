// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

void main() {
  test('pub get gets dependencies', () async {
    var process = await TestProcess.start('pub', ['run', 'mono_repo']);

    var output = await process.stdoutStream().join('\n');
    expect(output, '''Manage multiple packages in one source repository.

Usage: mono_repo <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  check       Check the state of the repository.
  help        Display help information for mono_repo.
  init        Initialize a new repository.
  presubmit   Run the travis presubmits locally.
  travis      Configure Travis-CI for child packages.

Run "mono_repo help <command>" for more information about a command.''');

    await process.shouldExit(0);
  });
}
