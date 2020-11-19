// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mono_repo/src/commands/travis/generate.dart';
import 'package:mono_repo/src/package_config.dart';
import 'package:mono_repo/src/yaml.dart';
import 'package:path/path.dart' as p;
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

void main() {
  glyph.ascii = false;

  group('mono_repo.yaml', () {
    group('stages', () {
      test('must be a list', () async {
        final monoConfigContent = toYaml({
          'travis': {'stages': 5}
        });
        await populateConfig(monoConfigContent);
        expect(
          testGenerateTravisConfig,
          throwsAParsedYamlException(
            startsWith(
              'line 2, column 11 of mono_repo.yaml: Unsupported value for '
              '"stages". `stages` must be an array.',
            ),
          ),
        );
      });

      test('must be string or map items', () async {
        final monoConfigContent = toYaml({
          'travis': {
            'stages': [5]
          }
        });
        await populateConfig(monoConfigContent);
        expect(
          testGenerateTravisConfig,
          throwsAParsedYamlException(
            startsWith(
              'line 3, column 5 of mono_repo.yaml: Unsupported value for '
              '"stages". All values must be String or Map instances.',
            ),
          ),
        );
      });

      test('map item must be exactly name + if – no less', () async {
        final monoConfigContent = toYaml({
          'travis': {
            'stages': [
              {'name': 'bob'}
            ]
          }
        });
        await populateConfig(monoConfigContent);
        expect(
          testGenerateTravisConfig,
          throwsAParsedYamlException(
              startsWith('line 3, column 7 of mono_repo.yaml: '
                  'Required keys are missing: if.')),
        );
      });

      test('map item must be exactly name + if – no more', () async {
        final monoConfigContent = toYaml({
          'travis': {
            'stages': [
              {'name': 'bob', 'if': 'thing', 'bob': 'other'}
            ]
          }
        });
        await populateConfig(monoConfigContent);
        expect(
          testGenerateTravisConfig,
          throwsAParsedYamlException(
            startsWith(
              'line 5, column 7 of mono_repo.yaml: Unrecognized keys: [bob]; '
              'supported keys: [name, if]',
            ),
          ),
        );
      });

      test('cannot have duplicate names', () async {
        final monoConfigContent = toYaml({
          'travis': {
            'stages': [
              {'name': 'bob', 'if': 'if'},
              {'name': 'bob', 'if': 'if'},
            ]
          }
        });
        await populateConfig(monoConfigContent);
        expect(
          testGenerateTravisConfig,
          throwsAParsedYamlException(
            startsWith(
              'line 3, column 5 of mono_repo.yaml: Unsupported value for '
              '"stages". `bob` appears more than once.',
            ),
          ),
        );
      });

      test('must match a configured stage from pkg_config', () async {
        final monoConfigContent = toYaml({
          'travis': {
            'stages': [
              {'name': 'bob', 'if': 'if'}
            ]
          }
        });
        await populateConfig(monoConfigContent);
        expect(
          () => testGenerateTravisConfig(printMatcher: 'package:sub_pkg'),
          throwsUserExceptionWith(
            'Error parsing mono_repo.yaml',
            'One or more stage was referenced in `mono_repo.yaml` that do not '
                'exist in any `mono_pkg.yaml` files: `bob`.',
          ),
        );
      });

      test('order is honored', () async {
        final monoConfigContent = toYaml({
          'travis': {
            'stages': ['a', 'b', 'c', 'd']
          }
        });
        await d.file('mono_repo.yaml', monoConfigContent).create();
        await d.dir('sub_pkg1', [
          d.file(monoPkgFileName, r'''
dart:
  - dev
stages:
  - a:
    - dartfmt
  - c:
    - test
'''),
          d.file('pubspec.yaml', '''
name: pkg_name
      ''')
        ]).create();

        await d.dir('sub_pkg2', [
          d.file(monoPkgFileName, r'''
dart:
  - dev
stages:
  - b:
    - dartfmt
  - d:
    - test
'''),
          d.file('pubspec.yaml', '''
name: pkg_name
      ''')
        ]).create();

        testGenerateTravisConfig(
          printMatcher: '''
package:sub_pkg1
package:sub_pkg2
Wrote `${p.join(d.sandbox, travisFileName)}`.
$ciScriptPathMessage''',
        );
        await d.file(travisFileName, contains(r'''
stages:
  - a
  - b
  - c
  - d
''')).validate();
      });

      test('if conditions work', () async {
        const monoConfigContent = r'''
travis:
  sudo: required
  addons:
    chrome: stable
  before_install:
  - tool/travis_setup.sh
  after_failure:
  - tool/report_failure.sh
  stages:
    - analyze_and_format
    - a
    - name: e2e_test_cron
      if: type IN (api, cron)
    - d
  branches:
    only:
      - master

merge_stages:
- analyze_and_format
''';
        await d.file('mono_repo.yaml', monoConfigContent).create();
        await d.dir('sub_pkg1', [
          d.file(monoPkgFileName, r'''
dart:
  - dev
stages:
  - a:
    - dartfmt
  - e2e_test_cron:
    - test
'''),
          d.file('pubspec.yaml', '''
name: pkg_name
      ''')
        ]).create();

        await d.dir('sub_pkg2', [
          d.file(monoPkgFileName, r'''
dart:
  - dev
stages:
  - analyze_and_format:
    - dartfmt
  - d:
    - test
'''),
          d.file('pubspec.yaml', '''
name: pkg_name
      ''')
        ]).create();

        testGenerateTravisConfig(
          printMatcher: '''
package:sub_pkg1
package:sub_pkg2
Wrote `${p.join(d.sandbox, travisFileName)}`.
$ciScriptPathMessage''',
        );
        await d.file(travisFileName, contains(r'''
stages:
  - analyze_and_format
  - a
  - name: e2e_test_cron
    if: "type IN (api, cron)"
  - d
''')).validate();
      });
    });

    test('travis value must be a Map', () async {
      final monoConfigContent = toYaml({'travis': 5});
      await populateConfig(monoConfigContent);

      expect(
        testGenerateTravisConfig,
        throwsAParsedYamlException(r'''
line 1, column 9 of mono_repo.yaml: Unsupported value for "travis". `travis` must be a Map.
  ╷
1 │ travis: 5
  │         ^
  ╵'''),
      );
    });

    group('invalid travis keys', () {
      for (var invalidValues in [
        ['cache'],
        ['jobs'],
        ['language'],
      ]) {
        test(invalidValues.toString(), () async {
          final invalidContent = Map.fromIterable(invalidValues);
          final monoConfigContent = toYaml({'travis': invalidContent});
          await populateConfig(monoConfigContent);

          expect(
            testGenerateTravisConfig,
            throwsAParsedYamlException(
              contains(
                ' of mono_repo.yaml: Unsupported value for '
                '"${invalidValues.single}". Contains illegal keys: '
                '${invalidValues.join(', ')}',
              ),
            ),
          );
        });
      }
    });
  });
}
