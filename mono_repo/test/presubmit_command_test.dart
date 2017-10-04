import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:mono_repo/src/presubmit_command.dart';
import 'package:mono_repo/src/travis_command.dart';
import 'package:mono_repo/src/travis_config.dart';

import 'shared.dart';

void main() {
  test('no $travisShPath', () async {
    await d.dir('pkg_a').create();

    expect(
        () => presubmit(rootDirectory: d.sandbox),
        throwsUserExceptionWith(
            'No $travisShPath file found, please run the `travis` command first.'));
  });

  group('golden path', () {
    setUp(() async {
      await d.dir('pkg_a', [
        d.file('.travis.yml', pkgAConfig),
        d.file('pubspec.yaml', '''
name: pkg_name
dev_dependencies:
  test: any
      '''),
        d.dir('test', [
          d.file('test.dart', basicTest),
        ]),
      ]).create();
      await d.dir('pkg_b', [
        d.file('.travis.yml', pkgBConfig),
        d.file('pubspec.yaml', '''
name: pkg_name
      '''),
      ]).create();

      await generateTravisConfig(rootDirectory: d.sandbox);
      await Process.run('chmod', ['+x', p.join('tool', 'travis.sh')],
          workingDirectory: d.sandbox);
      await Process.run('pub', ['get'],
          workingDirectory: p.join(d.sandbox, 'pkg_a'));
      await Process.run(
          'pub', ['global', 'activate', '-s', 'path', Directory.current.path]);
    });

    test('runs all tasks and packages', () async {
      var result = await Process.run(
          'pub', ['global', 'run', 'mono_repo', 'presubmit', '--sdk=dev'],
          workingDirectory: d.sandbox);
      expect(result.exitCode, 0,
          reason: 'stderr:\n${result.stderr}\nstdout:\n${result.stdout}');
      expect(result.stderr, '''
pkg_a
  Running task test:dev (success)
  Running task dartanalyzer:dev (success)
  Running task dartfmt:dev (success)
  Running task test:stable (skipped, mismatched sdk)
  Running task dartanalyzer:stable (skipped, mismatched sdk)
  Running task dartfmt:stable (skipped, mismatched sdk)
pkg_b
  Running task dartfmt:dev (success)
  Running task dartfmt:stable (skipped, mismatched sdk)
''');
    });

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
          workingDirectory: d.sandbox);
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
          workingDirectory: d.sandbox);
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
  });
}

final pkgAConfig = '''
language: dart
dart:
  - dev
  - stable

dart_task:
  - test
  - dartanalyzer
  - dartfmt
''';

final pkgBConfig = '''
language: dart
dart:
  - dev
  - stable

dart_task:
  - dartfmt
''';

final basicTest = '''
import 'package:test/test.dart';

main() {
  test('1 == 1', () {
    expect(1, equals(1));
  });
}
''';
