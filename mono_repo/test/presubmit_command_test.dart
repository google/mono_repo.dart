// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Tags(['presubmit-only'])
@OnPlatform({'windows': Skip('Cant run shell scripts on windows')})
import 'dart:io';

import 'package:io/ansi.dart';
import 'package:mono_repo/src/ci_shared.dart';
import 'package:mono_repo/src/commands/ci_script/generate.dart';
import 'package:mono_repo/src/commands/presubmit.dart';
import 'package:mono_repo/src/commands/pub.dart';
import 'package:mono_repo/src/package_config.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

void main() {
  group('error reporting', () {
    test('no $ciScriptPath', () async {
      await d.dir('pkg_a', [
        d.file('mono_pkg.yaml', ''),
        d.file('pubspec.yaml',
            '{"name":"_test", "environment": {"sdk": ">=2.7.0 <3.0.0"}}'),
      ]).create();

      expect(
        () => presubmit(RootConfig(rootDirectory: d.sandbox)),
        throwsUserExceptionWith(
          'No $ciScriptPath file found, please run the `generate` '
          'command first.',
        ),
      );
    });
  });

  group('golden path', () {
    late String repoPath;
    late String pkgAPath;
    String pkgBPath;

    setUpAll(() async {
      repoPath = Directory.systemTemp.createTempSync().path;
      pkgAPath = p.join(repoPath, 'pkg_a');
      Directory(pkgAPath).createSync();
      pkgBPath = p.join(repoPath, 'pkg_b');
      Directory(pkgBPath).createSync();

      File(p.join(pkgAPath, monoPkgFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync(pkgAConfig);
      File(p.join(pkgAPath, 'pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync(pkgAPubspec);
      File(p.join(pkgAPath, 'test', 'some_test.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync(basicTest);

      File(p.join(pkgBPath, monoPkgFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync(pkgBConfig);
      File(p.join(pkgBPath, 'pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync('''
name: pkg_b
environment:
  sdk: ">=2.7.0 <3.0.0"''');

      await overrideAnsiOutput(false, () async {
        await expectLater(
          () {
            final config = RootConfig(rootDirectory: repoPath);
            logPackages(config);
            generateCIScript(config);
          },
          prints(
            stringContainsInOrder(
              [
                'package:pkg_a',
                'package:pkg_b',
                'Make sure to mark `tool/ci.sh` as executable.',
              ],
            ),
          ),
        );
      });

      await Process.run(
        'chmod',
        ['+x', p.join('tool', 'ci.sh')],
        workingDirectory: repoPath,
      );
      await Process.run(dartPath, ['pub', 'get'], workingDirectory: pkgAPath);
      await Process.run(
        dartPath,
        ['pub', 'global', 'activate', '-s', 'path', Directory.current.path],
      );
    });

    tearDownAll(() {
      Directory(repoPath).deleteSync(recursive: true);
    });

    test(
      'runs all tasks and packages',
      () async {
        final result = await Process.run(dartPath,
            ['pub', 'global', 'run', 'mono_repo', 'presubmit', '--sdk=dev'],
            workingDirectory: repoPath);
        expect(result.exitCode, 0,
            reason: 'stderr:\n${result.stderr}\nstdout:\n${result.stdout}');
        expect(result.stdout, '''
pkg_a
  SDK: dev TASK: dart analyze
    success
  SDK: stable TASK: dart analyze
    skipped, mismatched sdk
  SDK: dev TASK: dart format --output=none --set-exit-if-changed .
    success
  SDK: stable TASK: dart format --output=none --set-exit-if-changed .
    skipped, mismatched sdk
  SDK: dev TASK: dart test
    success
  SDK: stable TASK: dart test
    skipped, mismatched sdk
pkg_b
  SDK: dev TASK: dart format --output=none --set-exit-if-changed .
    success
  SDK: stable TASK: dart format --output=none --set-exit-if-changed .
    skipped, mismatched sdk
''');
      },
      timeout: const Timeout.factor(2),
    );

    test('can filter by package', () async {
      final result = await Process.run(
          dartPath,
          [
            'pub',
            'global',
            'run',
            'mono_repo',
            'presubmit',
            '--sdk=dev',
            '-p',
            'pkg_b'
          ],
          workingDirectory: repoPath);
      expect(
        result.exitCode,
        0,
        reason: 'stderr:\n${result.stderr}\nstdout:\n${result.stdout}',
      );
      expect(result.stdout, '''
pkg_b
  SDK: dev TASK: dart format --output=none --set-exit-if-changed .
    success
  SDK: stable TASK: dart format --output=none --set-exit-if-changed .
    skipped, mismatched sdk
''');
    });

    test('can filter by task', () async {
      final result = await Process.run(
          dartPath,
          [
            'pub',
            'global',
            'run',
            'mono_repo',
            'presubmit',
            '--sdk=dev',
            '-t',
            'format'
          ],
          workingDirectory: repoPath);
      expect(result.exitCode, 0,
          reason: 'stderr:\n${result.stderr}\nstdout:\n${result.stdout}');
      expect(result.stdout, '''
pkg_a
  SDK: dev TASK: dart format --output=none --set-exit-if-changed .
    success
  SDK: stable TASK: dart format --output=none --set-exit-if-changed .
    skipped, mismatched sdk
pkg_b
  SDK: dev TASK: dart format --output=none --set-exit-if-changed .
    success
  SDK: stable TASK: dart format --output=none --set-exit-if-changed .
    skipped, mismatched sdk
''');
    });

    group('failing tasks', () {
      late File failingTestFile;
      setUp(() {
        failingTestFile = File(p.join(pkgAPath, 'test', 'failing_test.dart'))
          ..createSync()
          ..writeAsStringSync(failingTest);

        addTearDown(() {
          failingTestFile.deleteSync();
        });
      });

      test('cause an error and are reported', () async {
        final result = await Process.run(
            dartPath,
            [
              'pub',
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
        expect(
          result.stdout,
          startsWith('''
pkg_a
  SDK: dev TASK: dart test
    failure, '''),
        );
        printOnFailure(result.stdout as String);
        final stdOutString = result.stdout as String;
        const testFileName = 'pkg_a_test_dev.txt';
        final start = stdOutString.indexOf('failure, ') + 9;
        final end = stdOutString.indexOf(testFileName) + testFileName.length;
        final logPath = stdOutString.substring(start, end);
        final logFile = File(logPath);
        expect(
          logFile.existsSync(),
          isTrue,
          reason: 'Log file should exist: $logPath',
        );
        expect(logFile.readAsStringSync(), contains('Some tests failed'));
      });
    });
  });
}

const pkgAConfig = '''
sdk:
  - dev
  - stable

stages:
  - analyze_and_format:
    - analyze
    - format
  - unit_test:
    - test
''';

const pkgBConfig = '''
sdk:
  - dev
  - stable

stages:
  - format:
    - format
''';

const pkgAPubspec = '''
name: pkg_name
environment:
  sdk: ">=2.7.0 <3.0.0"
dev_dependencies:
  test: any
''';

const basicTest = '''
import 'package:test/test.dart';

main() {
  test('1 == 1', () {
    expect(1, equals(1));
  });
}
''';

const failingTest = '''
import 'package:test/test.dart';

main() {
  test('1 == 2', () {
    expect(1, equals(2));
  });
}
''';
