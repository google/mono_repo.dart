import 'dart:io';

import 'package:mono_repo/src/commands/github/github_yaml.dart';
import 'package:mono_repo/src/utilities.dart';
import 'package:mono_repo/src/yaml.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

void main() {
  test(
    'phase 5 features: ignore, pre_steps, post_steps, transitive paths',
    () async {
      await d.dir('pkg_a', [
        d.file('mono_pkg.yaml', '''
sdk:
  - dev
stages:
  - analyze:
    - analyze
'''),
        d.file('pubspec.yaml', '''
name: pkg_a
environment:
  sdk: '^3.0.0'
dependencies:
  pkg_b: any
'''),
      ]).create();

      await d.dir('pkg_b', [
        d.file('mono_pkg.yaml', '''
sdk:
  - dev
stages:
  - analyze:
    - analyze
'''),
        d.file('pubspec.yaml', '''
name: pkg_b
environment:
  sdk: '^3.0.0'
'''),
      ]).create();

      await d.dir('pkg_ignored', [
        d.file('mono_pkg.yaml', '''
sdk:
  - dev
stages:
  - analyze:
    - analyze
'''),
        d.file('pubspec.yaml', '''
name: pkg_ignored
environment:
  sdk: '^3.0.0'
'''),
      ]).create();

      await d.dir('pkg_hooks', [
        d.file('mono_pkg.yaml', '''
sdk:
  - dev
pre_steps:
  - run: echo "pre_step"
post_steps:
  - run: echo "post_step"
stages:
  - analyze:
    - analyze
'''),
        d.file('pubspec.yaml', '''
name: pkg_hooks
environment:
  sdk: '^3.0.0'
'''),
      ]).create();

      final monoConfigContent = toYaml({
        'ignore': ['pkg_ignored'],
      });
      await d.file('mono_repo.yaml', monoConfigContent).create();

      testGenerateConfig(
        printMatcher: stringContainsInOrder(['package:pkg_a']),
      );

      // Verify pkg_ignored is not generated
      final ignoredWorkflow = File(
        p.join(d.sandbox, githubWorkflowFilePath('pkg_ignored')),
      );
      expect(ignoredWorkflow.existsSync(), isFalse);

      // Verify pkg_hooks has pre_steps and post_steps
      await d
          .file(githubWorkflowFilePath('pkg_hooks'), contains('pre_step'))
          .validate();
      await d
          .file(githubWorkflowFilePath('pkg_hooks'), contains('post_step'))
          .validate();

      // Verify pkg_a has transitive paths (pkg_b)
      await d
          .file(githubWorkflowFilePath('pkg_a'), contains('pkg_b/**'))
          .validate();
    },
  );

  test('root package produces valid workflow file name and step ID', () async {
    await d.file('pubspec.yaml', '''
name: root_pkg
environment:
  sdk: '^3.0.0'
''').create();

    await d.dir('sub_pkg', [
      d.file('pubspec.yaml', '''
name: sub_pkg
environment:
  sdk: '^3.0.0'
'''),
    ]).create();

    await d.file('mono_repo.yaml', '''
defaults:
  sdk:
    - dev
  stages:
    - analyze:
      - analyze
''').create();

    testGenerateConfig(
      printMatcher: stringContainsInOrder(['package:.', 'package:sub_pkg']),
    );

    // Verify root package workflow is created using pubspec name
    // 'root_pkg.yaml'
    await d
        .file(githubWorkflowFilePath('root_pkg'), contains('package:root_pkg'))
        .validate();
  });

  test('custom on triggers specified as lists get paths appended', () async {
    await d.dir('pkg_a', [
      d.file('pubspec.yaml', '''
name: pkg_a
environment:
  sdk: '^3.0.0'
'''),
    ]).create();

    await d.file('mono_repo.yaml', '''
github:
  on:
    push:
      - main
defaults:
  sdk:
    - dev
  stages:
    - analyze:
      - analyze
''').create();

    testGenerateConfig(printMatcher: stringContainsInOrder(['package:pkg_a']));

    await d
        .file(githubWorkflowFilePath('pkg_a'), contains('paths:'))
        .validate();
  });

  test('SDK channel sorting ranks stable < beta < dev < main', () {
    final sdks = ['dev', 'stable', '3.8.0', 'main', 'pubspec', 'beta']
      ..sort(compareSdks);
    expect(sdks, ['pubspec', '3.8.0', 'stable', 'beta', 'dev', 'main']);
  });
}
