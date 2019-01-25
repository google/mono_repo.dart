// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:mockito/mockito.dart';
import 'package:mono_repo/src/commands/pub.dart';
import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

class _StartProcess extends Mock {
  Future<Process> call(
    String executable,
    List<String> arguments, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment,
    bool runInShell,
    ProcessStartMode mode,
  });
}

class _Process extends Mock implements Process {}

_StartProcess _mockProcessStart() {
  final mock = _StartProcess();

  final currentImpl = startProcess;
  startProcess = mock;
  addTearDown(() => startProcess = currentImpl);
  return mock;
}

void main() {
  test('pub get gets dependencies', () async {
    final mockProcess = _Process();
    when(mockProcess.exitCode).thenAnswer((_) => Future.value(0));

    final mock = _mockProcessStart();
    when(mock.call(any, any, mode: anyNamed('mode'), workingDirectory: anyNamed('workingDirectory')))
        .thenAnswer((_) => Future.value(mockProcess));

    var process =
        await TestProcess.start('pub', ['run', 'mono_repo', 'pub', 'get']);

    var output = await process.stdoutStream().join('\n');
    print(output);

    verifyInOrder([]);
    verifyNoMoreInteractions(mock);

    await process.shouldExit(0);
  });

  test('mono_repo without arguments prints help', () async {
    var process = await TestProcess.start('pub', ['run', 'mono_repo']);

    var output = await process.stdoutStream().join('\n');
    expect(output, _helpOutput);

    await process.shouldExit(0);
  });

  test('readme contains latest task output', () {
    var readme = File('README.md');

    expect(readme.readAsStringSync(), contains('```\n$_helpOutput\n```'));
  });
}

final _helpOutput = '''Manage multiple packages in one source repository.

Usage: mono_repo <command> [arguments]

Global options:
-h, --help              Print this usage information.
    --version           Prints the version of mono_repo.
    --[no-]recursive    Whether to recursively walk sub-directorys looking for packages.

Available commands:
  check       Check the state of the repository.
  help        Display help information for mono_repo.
  presubmit   Run the travis presubmits locally.
  pub         Run `pub get` or `pub upgrade` against all packages.
  travis      Configure Travis-CI for child packages.

Run "mono_repo help <command>" for more information about a command.''';
