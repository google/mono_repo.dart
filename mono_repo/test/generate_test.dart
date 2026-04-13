// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mono_repo/src/commands/ci_script/generate.dart';
import 'package:mono_repo/src/commands/github/github_yaml.dart';
import 'package:mono_repo/src/package_config.dart';
import 'package:mono_repo/src/yaml.dart';
import 'package:path/path.dart' as p;
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';
import 'src/expected_output.dart';

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
line 1, column 8 of mono_repo.yaml: Unsupported value for "extra". Only `github`, `pretty_ansi`, `pub_action`, `self_validate`, `coverage_service` keys are supported.
  ╷
1 │ extra: foo
  │        ^^^
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
        await d.file(ciScriptPath, contains('dart pub upgrade')).validate();
        await d
            .file(githubWorkflowFilePath('sub_pkg'), githubConfigOutput)
            .validate();
      });
    }
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

    testGenerateConfig(
      printMatcher:
          '''
package:sub_pkg
Wrote `${p.join(d.sandbox, githubWorkflowFilePath('sub_pkg'))}`.
Make sure to mark `tool/ci.sh` as executable.
  chmod +x tool/ci.sh
Wrote `${p.join(d.sandbox, 'tool/ci.sh')}`.''',
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

    testGenerateConfig(
      printMatcher:
          '''
package:pkg_a
package:pkg_b
Wrote `${p.join(d.sandbox, githubWorkflowFilePath('pkg_a'))}`.
Wrote `${p.join(d.sandbox, githubWorkflowFilePath('pkg_b'))}`.
Make sure to mark `tool/ci.sh` as executable.
  chmod +x tool/ci.sh
Wrote `${p.join(d.sandbox, 'tool/ci.sh')}`.''',
    );

    await d.file(ciScriptPath, contains('dart pub upgrade')).validate();
    await d.file(ciScriptPath, contains('dart pub upgrade')).validate();
    await d
        .file(githubWorkflowFilePath('pkg_a'), contains('package:pkg_a'))
        .validate();
    await d
        .file(githubWorkflowFilePath('pkg_b'), contains('package:pkg_b'))
        .validate();
  });

  group('mono_repo.yaml', () {
    test('self_validate set to `true`', () async {
      await populateConfig('self_validate: true');
      testGenerateConfig(
        printMatcher:
            '''
package:sub_pkg
  There are jobs defined that are not compatible with the package SDK constraint (^3.0.0): `1.23.0`.
Wrote `${p.join(d.sandbox, githubWorkflowFilePath('sub_pkg'))}`.
Wrote `${p.join(d.sandbox, githubWorkflowFilePath('mono_repo_self_validate'))}`.
Make sure to mark `tool/ci.sh` as executable.
  chmod +x tool/ci.sh
Wrote `${p.join(d.sandbox, 'tool/ci.sh')}`.''',
      );
      await d.file(ciScriptPath, contains('dart pub upgrade')).validate();
    });

    test('self_validate set to a stage name', () async {
      await populateConfig('self_validate: custom_stage');
      testGenerateConfig(
        printMatcher:
            '''
package:sub_pkg
  There are jobs defined that are not compatible with the package SDK constraint (^3.0.0): `1.23.0`.
Wrote `${p.join(d.sandbox, githubWorkflowFilePath('sub_pkg'))}`.
Wrote `${p.join(d.sandbox, githubWorkflowFilePath('mono_repo_self_validate'))}`.
Make sure to mark `tool/ci.sh` as executable.
  chmod +x tool/ci.sh
Wrote `${p.join(d.sandbox, 'tool/ci.sh')}`.''',
      );
      await d.file(ciScriptPath, contains('dart pub upgrade')).validate();
    });

    test(
      'disallows unsupported keys',
      () => _testBadConfig(
        {'other': 5},
        r'''
line 1, column 8 of mono_repo.yaml: Unsupported value for "other". Only `github`, `pretty_ansi`, `pub_action`, `self_validate`, `coverage_service` keys are supported.
  ╷
1 │ other: 5
  │        ^
  ╵''',
      ),
    );
  });

  group('pubspec validation', () {
    test('pubspec version valid', () async {
      await d.dir('pkg_a', [
        d.file(monoPkgFileName, r'''
sdk:
  - pubspec

stages:
  - analyze_and_format:
    - analyze: --fatal-infos .
      sdk: pubspec
'''),
        d.file('pubspec.yaml', '''
name: pkg_a
environment:
  sdk: '^3.0.0'
'''),
      ]).create();

      testGenerateConfig(
        printMatcher:
            '''
package:pkg_a
  `dart` values (pubspec) are not used and can be removed.
Wrote `${p.join(d.sandbox, githubWorkflowFilePath('pkg_a'))}`.
Make sure to mark `tool/ci.sh` as executable.
  chmod +x tool/ci.sh
Wrote `${p.join(d.sandbox, 'tool/ci.sh')}`.''',
      );
    });

    test('no SDK constraint - with job `pubspec` usage', () async {
      await d.dir('pkg_a', [
        d.file(monoPkgFileName, r'''
stages:
- analyze_and_format:
  - analyze: --fatal-infos .
    sdk: pubspec
'''),
        d.file('pubspec.yaml', '''
name: pkg_a
'''),
      ]).create();

      expect(
        testGenerateConfig,
        throwsAParsedYamlException(r'''
line 1, column 1 of pkg_a/mono_pkg.yaml: Missing key "sdk". `pubspec` is only valid for packages that have an environment->sdk value defined in `pubspec.yaml`.
  ╷
1 │ ┌ stages:
2 │ │ - analyze_and_format:
3 │ │   - analyze: --fatal-infos .
4 │ └     sdk: pubspec
  ╵'''),
      );
    });

    test('not supported with flutter', () async {
      await d.dir('pkg_a', [
        d.file(monoPkgFileName, r'''
stages:
- analyze_and_format:
  - analyze: --fatal-infos .
    sdk: pubspec
'''),
        d.file('pubspec.yaml', '''
name: pkg_a

environment:
  sdk: "^3.0.0"

dependencies:
  flutter:
    sdk: flutter
'''),
      ]).create();

      expect(
        testGenerateConfig,
        throwsAParsedYamlException(r'''
line 1, column 1 of pkg_a/mono_pkg.yaml: Missing key "sdk". `pubspec` is only valid for Dart packages (not Flutter).
  ╷
1 │ ┌ stages:
2 │ │ - analyze_and_format:
3 │ │   - analyze: --fatal-infos .
4 │ └     sdk: pubspec
  ╵'''),
      );
    });
  });
}

String _subPkgStandardOutput({bool withDependabot = false}) =>
    '''
package:sub_pkg
  There are jobs defined that are not compatible with the package SDK constraint (^3.0.0): `1.23.0`.
Wrote `${p.join(d.sandbox, githubWorkflowFilePath('sub_pkg'))}`.
${withDependabot ? 'Wrote `${p.join(d.sandbox, '.github/dependabot.yml')}`.\n' : ''}Make sure to mark `tool/ci.sh` as executable.
  chmod +x tool/ci.sh
Wrote `${p.join(d.sandbox, 'tool/ci.sh')}`.''';

Future<void> _testBadConfig(
  Object monoRepoYaml,
  Object expectedParsedYaml,
) async {
  final monoConfigContent = toYaml(monoRepoYaml);
  await populateConfig(monoConfigContent);
  expect(testGenerateConfig, throwsAParsedYamlException(expectedParsedYaml));
}
