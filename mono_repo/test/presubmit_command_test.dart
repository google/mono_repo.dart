// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:mono_repo/src/commands/presubmit.dart';
import 'package:mono_repo/src/commands/travis.dart';
import 'package:mono_repo/src/mono_config.dart';

import 'shared.dart';

void main() {
  group('error reporting', () {
    test('no $travisShPath', () async {
      await d.dir('pkg_a').create();

      expect(
          () => presubmit(rootDirectory: d.sandbox),
          throwsUserExceptionWith(
              'No $travisShPath file found, please run the `travis` '
              'command first.'));
    });
  });

  group('golden path', () {
    String repoPath;
    String pkgAPath;
    String pkgBPath;

    setUpAll(() async {
      repoPath = Directory.systemTemp.createTempSync().path;
      pkgAPath = p.join(repoPath, 'pkg_a');
      new Directory(pkgAPath).createSync();
      pkgBPath = p.join(repoPath, 'pkg_b');
      new Directory(pkgBPath).createSync();

      new File(p.join(pkgAPath, monoFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync(pkgAConfig);
      new File(p.join(pkgAPath, 'pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync(pkgAPubspec);
      new File(p.join(pkgAPath, 'test', 'test.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync(basicTest);

      new File(p.join(pkgBPath, monoFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync(pkgBConfig);
      new File(p.join(pkgBPath, 'pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync('name: pkg_b');

      await generateTravisConfig(rootDirectory: repoPath);
      await Process.run('chmod', ['+x', p.join('tool', 'travis.sh')],
          workingDirectory: repoPath);
      await Process.run('pub', ['get'], workingDirectory: pkgAPath);
      await Process.run(
          'pub', ['global', 'activate', '-s', 'path', Directory.current.path]);
    });

    tearDownAll(() {
      new Directory(repoPath).deleteSync(recursive: true);
    });

    test('runs all tasks and packages', () async {
      var result = await Process.run(
          'pub', ['global', 'run', 'mono_repo', 'presubmit', '--sdk=dev'],
          workingDirectory: repoPath);
      expect(result.exitCode, 0,
          reason: 'stderr:\n${result.stderr}\nstdout:\n${result.stdout}');
      expect(result.stderr, '''
pkg_a
  Running task dartanalyzer:dev (success)
  Running task dartanalyzer:stable (skipped, mismatched sdk)
  Running task dartfmt:dev (success)
  Running task dartfmt:stable (skipped, mismatched sdk)
  Running task test:dev (success)
  Running task test:stable (skipped, mismatched sdk)
pkg_b
  Running task dartfmt:dev (success)
  Running task dartfmt:stable (skipped, mismatched sdk)
''');
    }, timeout: new Timeout.factor(2));

    test('can filter by package', () async {
      var result = await Process.run(
          'pub',
          [
            'global',
            'run',
            'mono_repo',
            'presubmit',
            '--sdk=dev',
            '-p',
            'pkg_b'
          ],
          workingDirectory: repoPath);
      expect(result.exitCode, 0,
          reason: 'stderr:\n${result.stderr}\nstdout:\n${result.stdout}');
      expect(result.stderr, '''
pkg_b
  Running task dartfmt:dev (success)
  Running task dartfmt:stable (skipped, mismatched sdk)
''');
    });

    test('can filter by task', () async {
      var result = await Process.run(
          'pub',
          [
            'global',
            'run',
            'mono_repo',
            'presubmit',
            '--sdk=dev',
            '-t',
            'dartfmt'
          ],
          workingDirectory: repoPath);
      expect(result.exitCode, 0,
          reason: 'stderr:\n${result.stderr}\nstdout:\n${result.stdout}');
      expect(result.stderr, '''
pkg_a
  Running task dartfmt:dev (success)
  Running task dartfmt:stable (skipped, mismatched sdk)
pkg_b
  Running task dartfmt:dev (success)
  Running task dartfmt:stable (skipped, mismatched sdk)
''');
    });

    group('failing tasks', () {
      File failingTestFile;
      setUp(() {
        failingTestFile =
            new File(p.join(pkgAPath, 'test', 'failing_test.dart'))
              ..createSync()
              ..writeAsStringSync(failingTest);
      });
      tearDown(() {
        failingTestFile.deleteSync();
      });

      test('cause an error and are reported', () async {
        var result = await Process.run(
            'pub',
            [
              'global',
              'run',
              'mono_repo',
              'presubmit',
              '--sdk=dev',
              '-t',
              'test',
              '-p',
              'pkg_a',
            ],
            workingDirectory: repoPath);
        expect(result.exitCode, 1,
            reason: 'Any failing tasks should give a non-zero exit code');
        expect(result.stderr, startsWith('''
pkg_a
  Running task test:dev (failure, '''));
        var stdErrString = result.stderr as String;
        var start = stdErrString.indexOf('(failure, ') + 10;
        var end = stdErrString.indexOf(')');
        var logPath = stdErrString.substring(start, end);
        var logFile = new File(logPath);
        expect(logFile.existsSync(), isTrue);
        expect(logFile.readAsStringSync(), contains('Some tests failed'));
      });
    });
  });
}

final pkgAConfig = '''
dart:
  - dev
  - stable

stages:
  - analyze_and_format:
    - dartanalyzer 
    - dartfmt
  - unit_test:
    - test
''';

final pkgBConfig = '''
dart:
  - dev
  - stable

stages:
  - format:
    - dartfmt
''';

final pkgAPubspec = '''
name: pkg_name
dev_dependencies:
  test: any
''';

final basicTest = '''
import 'package:test/test.dart';

main() {
  test('1 == 1', () {
    expect(1, equals(1));
  });
}
''';

final failingTest = '''
import 'package:test/test.dart';

main() {
  test('1 == 2', () {
    expect(1, equals(2));
  });
}
''';
