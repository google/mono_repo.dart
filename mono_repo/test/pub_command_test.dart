// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:mono_repo/src/package_config.dart';
import 'package:test_process/test_process.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:path/path.dart' as p;

void main() {
  final monoRepoExecutable = p.join(p.current, 'bin', 'mono_repo.dart');

  test('help command pub output', () async {
    var process =
        await TestProcess.start('dart', [monoRepoExecutable, 'help', 'pub']);

    var output = await process.stdoutStream().join('\n');
    expect(output, _helpCommandPubOutput);

    await process.shouldExit(0);
  });

  test('--help is passed to pub', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    await d.dir('pkg_b', [
      d.file(monoPkgFileName),
      d.file('pubspec.yaml', '''
name: pkg_b
      ''')
    ]).create();

    var process = await TestProcess.start(
        'dart', [monoRepoExecutable, 'pub', '--help'],
        workingDirectory: d.sandbox);

    var actualOutput = await process.stderrStream().join('\n');

    var expected = Process.runSync('pub', ['--help']).stdout;

    expect(actualOutput, startsWith('Running `pub --help` across 2 packages.'));
    expect(actualOutput, contains(expected));

    await process.shouldExit(0);
  });

  test('pub subcommands support their normal arguments', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    await d.dir('pkg_b', [
      d.file(monoPkgFileName),
      d.file('pubspec.yaml', '''
name: pkg_b
      ''')
    ]).create();

    var process = await TestProcess.start(
        'dart', [monoRepoExecutable, 'pub', 'get', '--help'],
        workingDirectory: d.sandbox);

    var actualOutput = await process.stderrStream().join('\n');

    var expected =
        Process.runSync('pub', ['get', '--help'], workingDirectory: d.sandbox)
            .stdout;

    expect(actualOutput,
        startsWith('Running `pub get --help` across 2 packages.'));
    expect(actualOutput, contains(expected));

    await process.shouldExit(0);
  });

  test('a single package is referenced if there is only one', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    var process = await TestProcess.start(
        'dart', [monoRepoExecutable, 'pub', '--help'],
        workingDirectory: d.sandbox);

    var actualOutput = await process.stderrStream().join('\n');

    expect(actualOutput, startsWith('Running `pub --help` across 1 package.'));
  });

  test(
      'if there are no arguments, the `pub` command is still printed '
      'correctly', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    var process = await TestProcess.start('dart', [monoRepoExecutable, 'pub'],
        workingDirectory: d.sandbox);

    var actualOutput = await process.stderrStream().join('\n');

    expect(actualOutput, startsWith('Running `pub` across 1 package.'));
    expect(actualOutput, contains('Starting `pub` in `'));
  });

  // flutter doesn't need to be installed, it is okay if finding it fails
  test('a flutter dependency is handled correctly for get', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName),
      d.file('pubspec.yaml', '''
name: pkg_a
dependencies:
  flutter:
    sdk: flutter
      ''')
    ]).create();

    await d.dir('pkg_b', [
      d.file(monoPkgFileName),
      d.file('pubspec.yaml', '''
name: pkg_b
      ''')
    ]).create();

    var process = await TestProcess.start(
        'dart', [monoRepoExecutable, 'pub', 'get'],
        workingDirectory: d.sandbox);

    var actualOutput = await process.stderrStream().join('\n');

    expect(actualOutput, startsWith('Running `pub get` across 2 packages.'));
    expect(actualOutput, contains('Starting `pub get` in `'));
    expect(actualOutput, contains('Starting `flutter packages get` in `'));
  });

  // flutter doesn't need to be installed, it is okay if finding it fails
  test('a flutter dependency is handled correctly for other commands',
      () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName),
      d.file('pubspec.yaml', '''
name: pkg_a
dependencies:
  flutter:
    sdk: flutter
      ''')
    ]).create();

    await d.dir('pkg_b', [
      d.file(monoPkgFileName),
      d.file('pubspec.yaml', '''
name: pkg_b
      ''')
    ]).create();

    var process = await TestProcess.start(
        'dart', [monoRepoExecutable, 'pub', '--help'],
        workingDirectory: d.sandbox);

    var actualOutput = await process.stderrStream().join('\n');

    expect(actualOutput, startsWith('Running `pub --help` across 2 packages.'));
    expect(actualOutput, contains('Starting `pub --help` in `'));
    expect(actualOutput, contains('Starting `flutter --help` in `'));
  });
}

final _helpCommandPubOutput = '''Run a `pub` command across all packages.

Usage: mono_repo pub [arguments]
Any arguments given are passed verbatim to `pub`.

If a particular package uses Flutter, `flutter` is used rather than `pub`:
- If the arguments begin with `get` or `upgrade`, `flutter packages` is used.
- Otherwise, `flutter` is used.

Run "mono_repo help" to see global options.''';
