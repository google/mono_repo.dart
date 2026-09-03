// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:mono_repo/src/ci_shared.dart';
import 'package:mono_repo/src/commands/ci_script/generate.dart';
import 'package:mono_repo/src/commands/github/github_yaml.dart';
import 'package:mono_repo/src/package_config.dart';
import 'package:mono_repo/src/yaml.dart';
import 'package:path/path.dart' as p;
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

void main() {
  glyph.ascii = false;

  test('unsupported toplevel key', () async {
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, r'''
sdk:
  - dev

stages:
  - unit_test:
    - test
'''),
      d.file('pubspec.yaml', '''
name: pkg_name
environment:
  sdk: '^3.0.0'
      '''),
    ]).create();

    await _testBadConfig(
      {'extra': 'foo'},
      r'''
line 1, column 8 of mono_repo.yaml: Unsupported value for "extra". Only `github`, `pretty_ansi`, `pub_action`, `self_validate`, `coverage_service`, `defaults`, `ignore` keys are supported.
  ╷
1 │ extra: "foo"
  │        ^^^^^
  ╵''',
    );
  });

  test('fails with unsupported configuration', () async {
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, r'''
sdk:
  - dev

stages:
  - unit_test:
    # Doing the hole xvfb thing is broken - for now!
    - test: --platform chrome
'''),
      d.file('pubspec.yaml', '''
name: pkg_name
environment:
  sdk: '^3.0.0'
      '''),
    ]).create();

    testGenerateConfig(
      printMatcher: stringContainsInOrder([
        'package:sub_pkg',
        'Make sure to mark `tool/ci.sh` as executable.\n',
        '  chmod +x tool/ci.sh\n',
      ]),
    );
  });

  group('simple bits for configurations', () {
    for (var value in const [true, false, null]) {
      test('value `$value`', () async {
        final monoConfigContent = toYaml({'github': value});
        await populateConfig(monoConfigContent);

        testGenerateConfig(printMatcher: _subPkgStandardOutput());
        validateSandbox('simple_ci.sh', ciScriptPath);
        validateSandbox(
          'simple_github.yaml',
          githubWorkflowFilePath('sub_pkg'),
        );
      });
    }

    test('custom permissions', () async {
      final monoConfigContent = toYaml({
        'github': {
          'permissions': {'contents': 'read'},
        },
      });
      await populateConfig(monoConfigContent);

      testGenerateConfig(printMatcher: _subPkgStandardOutput());

      final workflowFile = File(
        p.join(d.sandbox, githubWorkflowFilePath('sub_pkg')),
      );
      expect(
        workflowFile.readAsStringSync(),
        contains('permissions:\n  contents: "read"'),
      );
    });
  });

  test('no package', () async {
    await d.dir('sub_pkg').create();

    expect(
      testGenerateConfig,
      throwsUserExceptionWith(
        'No packages found.',
        details:
            'Each target package directory must contain a '
            '`mono_pkg.yaml` file.',
      ),
    );
  });

  test('empty $monoPkgFileName file', () async {
    await d.dir('sub_pkg', [
      d.file('mono_pkg.yaml', 'sdk: [dev]'),
      d.file('pubspec.yaml', '''
name: pkg_name
environment:
  sdk: '^3.0.0'
      '''),
    ]).create();

    final workflowPath = p.normalize(
      p.join(d.sandbox, githubWorkflowFilePath('sub_pkg')),
    );
    final ciScriptPathNormalized = p.normalize(p.join(d.sandbox, 'tool/ci.sh'));
    testGenerateConfig(
      printMatcher: stringContainsInOrder([
        'package:sub_pkg\n',
        'Wrote `$workflowPath`.\n',
        'Make sure to mark `tool/ci.sh` as executable.\n',
        '  chmod +x tool/ci.sh\n',
        'Wrote `$ciScriptPathNormalized`.',
      ]),
    );
    await d.file(ciScriptPath, contains('dart pub upgrade')).validate();
  });

  test('two packages', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName, r'''
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
      '''),
    ]).create();

    await d.dir('pkg_b', [
      d.file(monoPkgFileName, r'''
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

    final pkgAWorkflowPath = p.normalize(
      p.join(d.sandbox, githubWorkflowFilePath('pkg_a')),
    );
    final pkgBWorkflowPath = p.normalize(
      p.join(d.sandbox, githubWorkflowFilePath('pkg_b')),
    );
    testGenerateConfig(
      printMatcher: stringContainsInOrder([
        'package:pkg_a',
        'package:pkg_b',
        'Wrote `$pkgAWorkflowPath`.',
        'Wrote `$pkgBWorkflowPath`.',
      ]),
    );
  });

  test('pubspec validation not supported with flutter', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName, r'''
stages:
- analyze_and_format:
  - analyze: .
    sdk: pubspec
'''),
      d.file('pubspec.yaml', '''
name: pkg_a
environment:
  sdk: '>=2.12.0 <3.0.0'
dependencies:
  flutter:
    sdk: flutter
'''),
    ]).create();

    expect(
      testGenerateConfig,
      throwsAParsedYamlException('''
line 1, column 1 of pkg_a${p.separator}mono_pkg.yaml: Missing key "sdk". `pubspec` is only valid for Dart packages (not Flutter).
  ╷
1 │ ┌ stages:
2 │ │ - analyze_and_format:
3 │ │   - analyze: .
4 │ └     sdk: pubspec
  ╵'''),
    );
  });

  test(
    'package features: ignore, pre_steps, post_steps, transitive paths',
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

  test('schedule triggers are preserved without paths or branches', () async {
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
    schedule:
      - cron: "0 0 * * 0"
defaults:
  sdk:
    - dev
  stages:
    - analyze:
      - analyze
''').create();

    testGenerateConfig(printMatcher: stringContainsInOrder(['package:pkg_a']));

    await d
        .file(
          githubWorkflowFilePath('pkg_a'),
          contains('schedule:\n    - cron: "0 0 * * 0"'),
        )
        .validate();
  });
}

String _subPkgStandardOutput({bool withDependabot = false}) {
  final workflowPath = p.normalize(
    p.join(d.sandbox, githubWorkflowFilePath('sub_pkg')),
  );
  final setupDartPath = p.normalize(
    p.join(d.sandbox, '.github/actions/setup-dart/action.yml'),
  );
  final setupFlutterPath = p.normalize(
    p.join(d.sandbox, '.github/actions/setup-flutter/action.yml'),
  );
  final ciScriptPathNormalized = p.normalize(p.join(d.sandbox, 'tool/ci.sh'));
  return '''
package:sub_pkg
  There are jobs defined that are not compatible with the package SDK constraint (^3.0.0): `1.23.0`.
Wrote `$workflowPath`.
Wrote `$setupDartPath`.
Wrote `$setupFlutterPath`.
${withDependabot ? 'Wrote `${p.normalize(p.join(d.sandbox, ".github/dependabot.yml"))}`.\n' : ''}${scriptLines('tool/ci.sh').join('\n')}
Wrote `$ciScriptPathNormalized`.''';
}

Future<void> _testBadConfig(
  Object monoRepoYaml,
  Object expectedParsedYaml,
) async {
  final monoConfigContent = toYaml(monoRepoYaml);
  await populateConfig(monoConfigContent);
  expect(testGenerateConfig, throwsAParsedYamlException(expectedParsedYaml));
}
