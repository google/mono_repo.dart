// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:mono_repo/mono_repo.dart';
import 'package:mono_repo/src/commands/ci_script/generate.dart';
import 'package:mono_repo/src/commands/github/generate.dart'
    show githubActionYamlPath;
import 'package:mono_repo/src/commands/travis/generate.dart'
    show travisFileName;
import 'package:mono_repo/src/package_config.dart';
import 'package:mono_repo/src/version.dart';
import 'package:mono_repo/src/yaml.dart';
import 'package:path/path.dart' as p;
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';
import 'src/expected_output.dart';

void main() {
  glyph.ascii = false;

  test('no package', () async {
    await d.dir('sub_pkg').create();

    expect(
      testGenerateBothConfig,
      throwsUserExceptionWith(
        'No packages found.',
        'Each target package directory must contain a `mono_pkg.yaml` file.',
      ),
    );
  });

  test('$monoPkgFileName with non-Map contents', () async {
    await d.dir('sub_pkg', [
      d.file('mono_pkg.yaml', 'bob'),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    final path = p.join('sub_pkg', 'mono_pkg.yaml');
    expect(
      testGenerateBothConfig,
      throwsUserExceptionWith('The contents of `$path` must be a Map.', isNull),
    );
  });

  test('empty $monoPkgFileName file', () async {
    await d.dir('sub_pkg', [
      d.file('mono_pkg.yaml', '# just a comment!'),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
      () => testGenerateBothConfig(
        printMatcher: '''
package:sub_pkg
  `dart` values () are not used and can be removed.
  `os` values () are not used and can be removed.
Wrote `${p.join(d.sandbox, travisFileName)}`.
Wrote `${p.join(d.sandbox, githubActionYamlPath)}`.''',
      ),
      throwsUserExceptionWith(
        'No entries created. Check your nested `$monoPkgFileName` files.',
        isNull,
      ),
    );
  });

  test('fails with unsupported configuration', () async {
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, r'''
dart:
  - dev

stages:
  - unit_test:
    # Doing the hole xvfb thing is broken - for now!
    - test: --platform chrome
      xvfb: true
'''),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
      testGenerateBothConfig,
      throwsAParsedYamlException(
        startsWith(
          'line 8, column 7 of ${p.join('sub_pkg', 'mono_pkg.yaml')}: '
          'Extra config options are not currently supported.',
        ),
      ),
    );
  });

  test('fails with legacy file name', () async {
    await d.dir('sub_pkg', [
      d.file('.mono_repo.yml', ''),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
      testGenerateBothConfig,
      throwsUserExceptionWith(
        'Found legacy package configuration file '
            '(".mono_repo.yml") in `sub_pkg`.',
        'Rename to "mono_pkg.yaml".',
      ),
    );
  });

  test('conflicting stage orders are not allowed', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName, r'''
dart:
 - dev

stages:
  - format:
    - dartfmt
  - analyze:
    - dartanalyzer
'''),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    await d.dir('pkg_b', [
      d.file(monoPkgFileName, r'''
dart:
 - dev

stages:
  - analyze:
    - dartanalyzer
  - format:
    - dartfmt: sdk
'''),
      d.file('pubspec.yaml', '''
name: pkg_b
      ''')
    ]).create();

    expect(
      () => testGenerateBothConfig(
        printMatcher: '''
package:pkg_a
package:pkg_b''',
      ),
      throwsUserExceptionWith(
        'Not all packages agree on `stages` ordering, found a cycle '
        'between the following stages: `analyze`, `format`.',
        isNull,
      ),
    );
  });

  group('--validate', () {
    setUp(() async {
      await d.dir('sub_pkg', [
        d.file(monoPkgFileName, testConfig2),
        d.file('pubspec.yaml', '''
name: pkg_name
      ''')
      ]).create();
    });

    test('throws if there is no generated config', () async {
      expect(
        () => testGenerateBothConfig(
          validateOnly: true,
          printMatcher: 'package:sub_pkg',
        ),
        throwsA(isA<UserException>()),
      );
    });

    test("throws if the previous config doesn't match", () async {
      // TODO: validate GitHub case
      await d.file(travisFileName, '').create();
      await d.dir('tool', [
        d.file('travis.sh', ''),
      ]).create();
      expect(
        () => testGenerateBothConfig(
          validateOnly: true,
          printMatcher: 'package:sub_pkg',
        ),
        throwsA(isA<UserException>()),
      );
    });

    test("doesn't throw if the previous config is up to date", () async {
      testGenerateBothConfig(
        printMatcher: _subPkgStandardOutput,
      );

      // Just check that this doesn't throw.
      testGenerateBothConfig(printMatcher: '''
package:sub_pkg
Wrote `${p.join(d.sandbox, travisFileName)}`.
Wrote `${p.join(d.sandbox, githubActionYamlPath)}`.
Wrote `${p.join(d.sandbox, ciScriptPath)}`.''');
    });
  });

  test('complete travis.yml file', () async {
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, testConfig2),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    testGenerateBothConfig(
      printMatcher: _subPkgStandardOutput,
    );
    // TODO: validate GitHub case
    await d.file(travisFileName, travisYamlOutput).validate();
    await d.file(ciScriptPath, ciShellOutput).validate();
  });

  test('incompatible SDK constraints', () async {
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, testConfig2),
      d.file('pubspec.yaml', '''
name: pkg_name
environment:
  sdk: '>=2.1.0 <3.0.0'
''')
    ]).create();

    testGenerateBothConfig(
      printMatcher: '''
package:sub_pkg
  There are jobs defined that are not compatible with the package SDK constraint (>=2.1.0 <3.0.0): `1.23.0`.
$_writeScriptOutput''',
    );

    // TODO: validate GitHub case
    await d.file(travisFileName, travisYamlOutput).validate();
    await d.file(ciScriptPath, ciShellOutput).validate();
  });

  test('two flavors of dartfmt', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName, r'''
dart:
 - stable
 - dev

stages:
  - format:
    - dartfmt

cache:
  directories:
    - .dart_tool
    - /some_repo_root_dir
'''),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    await d.dir('pkg_b', [
      d.file(monoPkgFileName, r'''
dart:
 - dev

stages:
  - format:
    - dartfmt: sdk

cache:
  directories:
    - .dart_tool
    - /some_repo_root_dir
'''),
      d.file('pubspec.yaml', '''
name: pkg_b
      ''')
    ]).create();

    testGenerateBothConfig(
      printMatcher: '''
package:pkg_a
package:pkg_b
$_writeScriptOutput''',
    );

    // TODO: validate GitHub case
    await d.file(travisFileName, r'''
language: dart

jobs:
  include:
    - stage: format
      name: "SDK: dev; PKG: pkg_a; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: dev
      os: linux
      env: PKGS="pkg_a"
      script: tool/ci.sh dartfmt
    - stage: format
      name: "SDK: stable; PKG: pkg_a; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: stable
      os: linux
      env: PKGS="pkg_a"
      script: tool/ci.sh dartfmt
    - stage: format
      name: "SDK: dev; PKG: pkg_b; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: dev
      os: linux
      env: PKGS="pkg_b"
      script: tool/ci.sh dartfmt

stages:
  - format

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - $HOME/.pub-cache
    - /some_repo_root_dir
    - pkg_a/.dart_tool
    - pkg_b/.dart_tool
''').validate();

    await d.file(ciScriptPath, contains(r'''
      case ${TASK} in
      dartfmt)
        echo 'dartfmt -n --set-exit-if-changed .'
        dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
        ;;
      *)
        echo -e "\033[31mUnknown TASK '${TASK}' - TERMINATING JOB\033[0m"
        exit 64
        ;;
      esac
''')).validate();
  });

  test('two flavors of dartfmt with different arguments', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName, r'''
dart:
 - stable
 - dev

stages:
  - format:
    - dartfmt: sdk

cache:
  directories:
    - .dart_tool
    - /some_repo_root_dir
'''),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    await d.dir('pkg_b', [
      d.file(monoPkgFileName, r'''
dart:
 - dev

stages:
  - format:
    - dartfmt: --dry-run --fix --set-exit-if-changed .

cache:
  directories:
    - .dart_tool
    - /some_repo_root_dir
'''),
      d.file('pubspec.yaml', '''
name: pkg_b
      ''')
    ]).create();

    testGenerateBothConfig(
      printMatcher: '''
package:pkg_a
package:pkg_b
$_writeScriptOutput''',
    );

    // TODO: validate GitHub case
    await d.file(travisFileName, r'''
language: dart

jobs:
  include:
    - stage: format
      name: "SDK: dev; PKG: pkg_a; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: dev
      os: linux
      env: PKGS="pkg_a"
      script: tool/ci.sh dartfmt_0
    - stage: format
      name: "SDK: stable; PKG: pkg_a; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: stable
      os: linux
      env: PKGS="pkg_a"
      script: tool/ci.sh dartfmt_0
    - stage: format
      name: "SDK: dev; PKG: pkg_b; TASKS: `dartfmt --dry-run --fix --set-exit-if-changed .`"
      dart: dev
      os: linux
      env: PKGS="pkg_b"
      script: tool/ci.sh dartfmt_1

stages:
  - format

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - $HOME/.pub-cache
    - /some_repo_root_dir
    - pkg_a/.dart_tool
    - pkg_b/.dart_tool
''').validate();

    await d.file(ciScriptPath, contains(r'''
      case ${TASK} in
      dartfmt_0)
        echo 'dartfmt -n --set-exit-if-changed .'
        dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
        ;;
      dartfmt_1)
        echo 'dartfmt --dry-run --fix --set-exit-if-changed .'
        dartfmt --dry-run --fix --set-exit-if-changed . || EXIT_CODE=$?
        ;;
      *)
        echo -e "\033[31mUnknown TASK '${TASK}' - TERMINATING JOB\033[0m"
        exit 64
        ;;
      esac
''')).validate();
  });

  test('missing `dart` key', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName, r'''
stages:
  - format:
    - dartfmt:
'''),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    expect(
      testGenerateBothConfig,
      throwsAParsedYamlException('''
line 3, column 7 of ${p.normalize('pkg_a/mono_pkg.yaml')}: A "dart" key is required.
  ╷
3 │     - dartfmt:
  │       ^^^^^^^^
  ╵'''),
    );
  });

  test('top-level `dart` and `os` key values are a no-op with group overrides',
      () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName, r'''
dart:
- unneeded
os:
- unneeded

stages:
  - analyze:
    - group:
        - dartanalyzer
        - dartfmt
      dart:
        - dev
      os:
        - osx
    - dartanalyzer:
      dart:
        - 1.23.0
      os:
        - windows
  - unit_test:
    - description: "chrome tests"
      test: --platform chrome
      dart: dev
      os: macos
    - test: --preset travis
      dart: stable
      os: linux
'''),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    testGenerateBothConfig(
      printMatcher: '''
package:pkg_a
  `dart` values (unneeded) are not used and can be removed.
  `os` values (unneeded) are not used and can be removed.
$_writeScriptOutput''',
    );

    // TODO: validate GitHub case
    await d.file(travisFileName, r'''
language: dart

jobs:
  include:
    - stage: analyze
      name: "SDK: 1.23.0; PKG: pkg_a; TASKS: `dartanalyzer .`"
      dart: "1.23.0"
      os: windows
      env: PKGS="pkg_a"
      script: tool/ci.sh dartanalyzer
    - stage: analyze
      name: "SDK: dev; PKG: pkg_a; TASKS: [`dartanalyzer .`, `dartfmt -n --set-exit-if-changed .`]"
      dart: dev
      os: osx
      env: PKGS="pkg_a"
      script: tool/ci.sh dartanalyzer dartfmt
    - stage: unit_test
      name: "SDK: dev; PKG: pkg_a; TASKS: chrome tests"
      dart: dev
      os: macos
      env: PKGS="pkg_a"
      script: tool/ci.sh test_0
    - stage: unit_test
      name: "SDK: stable; PKG: pkg_a; TASKS: `pub run test --preset travis`"
      dart: stable
      os: linux
      env: PKGS="pkg_a"
      script: tool/ci.sh test_1

stages:
  - analyze
  - unit_test

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - $HOME/.pub-cache
''').validate();
    await d.file(ciScriptPath, ciShellOutput).validate();
  });

  test(
    'command values must be either a String or a List containing strings',
    () async {
      await d.dir('pkg_a', [
        d.file(monoPkgFileName, r'''
dart:
- dev

stages:
- unit_test:
  - command: {a:b}
'''),
        d.file('pubspec.yaml', '''
name: pkg_a
''')
      ]).create();

      expect(
        testGenerateBothConfig,
        throwsAParsedYamlException('''
line 6, column 14 of ${p.join('pkg_a', 'mono_pkg.yaml')}: Unsupported value for "command". Only supports a string or array of strings
  ╷
6 │   - command: {a:b}
  │              ^^^^^
  ╵'''),
      );
    },
  );

  test('bad yaml', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName, r'''
dart:
- dev

stages:
- unit_test
  - before_script: "echo hi"
''')
    ]).create();

    expect(
      testGenerateBothConfig,
      throwsAParsedYamlException('''
line 6, column 18 of ${p.join('pkg_a', 'mono_pkg.yaml')}: Mapping values are not allowed here. Did you miss a colon earlier?
  ╷
6 │   - before_script: "echo hi"
  │                  ^
  ╵'''),
    );
  });

  test('double digit commands', () async {
    final lines = Iterable.generate(
            11,
            (i) =>
                '    - test: --preset travis --total-shards 9 --shard-index $i')
        .join('\n');

    await d.dir('pkg_a', [
      d.file('pubspec.yaml', '''
name: pkg_a
'''),
      d.file(monoPkgFileName, '''
dart:
- dev

stages:
  - unit_test:
$lines
''')
    ]).create();

    testGenerateBothConfig(printMatcher: isNotEmpty);

    await d
        .file(
          ciScriptPath,
          stringContainsInOrder([
            'test_00)',
            'test_10)',
          ]),
        )
        .validate();
  });

  group('mono_repo.yaml', () {
    Future populateConfig(String monoRepoContent) async {
      await d.file('mono_repo.yaml', monoRepoContent).create();
      await d.dir('sub_pkg', [
        d.file(monoPkgFileName, testConfig2),
        d.file('pubspec.yaml', '''
name: pkg_name
      ''')
      ]).create();
    }

    Future<void> validConfig(
      String monoRepoContent,
      Object expectedTravisContent,
    ) async {
      await populateConfig(monoRepoContent);

      // TODO: validate GitHub case
      await d.nothing(travisFileName).validate();
      await d.nothing(ciScriptPath).validate();

      testGenerateBothConfig(
        printMatcher: _subPkgStandardOutput,
      );

      // TODO: validate GitHub case
      await d.file(travisFileName, expectedTravisContent).validate();
      await d.file(ciScriptPath, ciShellOutput).validate();
    }

    test('empty travis.yml file', () async {
      await validConfig('', travisYamlOutput);
    });

    test('pkg:build integration travis.yml file', () async {
      await validConfig(
        r'''
travis:
  sudo: required
  addons:
    chrome: stable
  branches:
    only:
      - master
      - not_master
  after_failure:
  - tool/report_failure.sh
''',
        contains('''
language: dart

# Custom configuration
sudo: required
addons:
  chrome: stable
branches:
  only:
    - master
    - not_master
after_failure:
  - tool/report_failure.sh

jobs:
  include:
'''),
      );
    });

    test('only supports a travis key', () async {
      final monoConfigContent = toYaml({
        'other': {'stages': 5}
      });
      await populateConfig(monoConfigContent);
      expect(
        testGenerateBothConfig,
        throwsAParsedYamlException(r'''
line 2, column 3 of mono_repo.yaml: Unsupported value for "other". Only `github`, `merge_stages`, `pretty_ansi`, `pub_action`, `self_validate`, `travis` keys are supported.
  ╷
2 │   stages: 5
  │   ^^^^^^^^^
  ╵'''),
      );
    });

    group('stages', () {
      test('must be a list', () async {
        final monoConfigContent = toYaml({
          'travis': {'stages': 5}
        });
        await populateConfig(monoConfigContent);
        expect(
          testGenerateBothConfig,
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
          testGenerateBothConfig,
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
          testGenerateBothConfig,
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
          testGenerateBothConfig,
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
          testGenerateBothConfig,
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
          () => testGenerateBothConfig(printMatcher: 'package:sub_pkg'),
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

        testGenerateBothConfig(
          printMatcher: '''
package:sub_pkg1
package:sub_pkg2
$_writeScriptOutput''',
        );
        // TODO: validate GitHub case
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

        testGenerateBothConfig(
          printMatcher: '''
package:sub_pkg1
package:sub_pkg2
$_writeScriptOutput''',
        );
        // TODO: validate GitHub case
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

    group('merge_stages', () {
      test('must be a list', () async {
        final monoConfigContent = toYaml({
          'merge_stages': {'stages': 5}
        });
        await populateConfig(monoConfigContent);
        expect(
          testGenerateBothConfig,
          throwsAParsedYamlException(
            startsWith(
              'line 2, column 3 of mono_repo.yaml: Unsupported value for '
              '"merge_stages". `merge_stages` must be an array.',
            ),
          ),
        );
      });

      test('must be String items', () async {
        final monoConfigContent = toYaml({
          'merge_stages': [5]
        });
        await populateConfig(monoConfigContent);
        expect(
          testGenerateBothConfig,
          throwsAParsedYamlException(
            startsWith(
              'line 2, column 3 of mono_repo.yaml: Unsupported value for '
              '"merge_stages". All values must be strings.',
            ),
          ),
        );
      });

      test('must match a configured stage from pkg_config', () async {
        final monoConfigContent = toYaml({
          'merge_stages': ['bob']
        });
        await populateConfig(monoConfigContent);
        expect(
          () => testGenerateBothConfig(printMatcher: 'package:sub_pkg'),
          throwsUserExceptionWith(
            'Error parsing mono_repo.yaml',
            'One or more stage was referenced in `mono_repo.yaml` that do not '
                'exist in any `mono_pkg.yaml` files: `bob`.',
          ),
        );
      });

      test('should merge correctly', () async {
        await d.file('mono_repo.yaml', '''
merge_stages: [analyze]
''').create();

        await d.dir('pkg_a', [
          d.file(monoPkgFileName, r'''
dart:
 - stable

stages:
  - analyze:
    - group:
        - dartanalyzer
        - dartfmt
  - unit_test:
    - description: "chrome tests"
      test: --platform chrome
    - test: --preset travis
'''),
          d.file('pubspec.yaml', r'''
name: pkg_a
''')
        ]).create();
        await d.dir('pkg_b', [
          d.file(monoPkgFileName, r'''
dart:
 - stable

stages:
  - analyze:
    - group:
        - dartanalyzer
        - dartfmt
  - unit_test:
    - description: "chrome tests"
      test: --platform chrome
    - test: --preset travis
'''),
          d.file('pubspec.yaml', '''
name: pkg_b
      ''')
        ]).create();

        testGenerateBothConfig(
          printMatcher: '''
package:pkg_a
package:pkg_b
$_writeScriptOutput''',
        );

        // TODO: validate GitHub case
        await d.file(travisFileName, r'''
language: dart

jobs:
  include:
    - stage: analyze
      name: "SDK: stable; PKGS: pkg_a, pkg_b; TASKS: [`dartanalyzer .`, `dartfmt -n --set-exit-if-changed .`]"
      dart: stable
      os: linux
      env: PKGS="pkg_a pkg_b"
      script: tool/ci.sh dartanalyzer dartfmt
    - stage: unit_test
      name: "SDK: stable; PKG: pkg_a; TASKS: chrome tests"
      dart: stable
      os: linux
      env: PKGS="pkg_a"
      script: tool/ci.sh test_0
    - stage: unit_test
      name: "SDK: stable; PKG: pkg_a; TASKS: `pub run test --preset travis`"
      dart: stable
      os: linux
      env: PKGS="pkg_a"
      script: tool/ci.sh test_1
    - stage: unit_test
      name: "SDK: stable; PKG: pkg_b; TASKS: chrome tests"
      dart: stable
      os: linux
      env: PKGS="pkg_b"
      script: tool/ci.sh test_0
    - stage: unit_test
      name: "SDK: stable; PKG: pkg_b; TASKS: `pub run test --preset travis`"
      dart: stable
      os: linux
      env: PKGS="pkg_b"
      script: tool/ci.sh test_1

stages:
  - analyze
  - unit_test

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - $HOME/.pub-cache
''').validate();
        await d.file(ciScriptPath, ciShellOutput).validate();
      });
    });

    test('travis value must be a Map', () async {
      final monoConfigContent = toYaml({'travis': 5});
      await populateConfig(monoConfigContent);

      expect(
        testGenerateBothConfig,
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
            testGenerateBothConfig,
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

    group('pub_action', () {
      test('value must be a String', () async {
        final monoConfigContent = toYaml({'pub_action': 42});
        await populateConfig(monoConfigContent);

        expect(
          testGenerateBothConfig,
          throwsAParsedYamlException(r'''
line 1, column 13 of mono_repo.yaml: Unsupported value for "pub_action". Value must be one of: `get`, `upgrade`.
  ╷
1 │ pub_action: 42
  │             ^^
  ╵'''),
        );
      });

      test('value must be in allowed list', () async {
        final monoConfigContent = toYaml({'pub_action': 'bob'});
        await populateConfig(monoConfigContent);

        expect(
          testGenerateBothConfig,
          throwsAParsedYamlException(r'''
line 1, column 13 of mono_repo.yaml: Unsupported value for "pub_action". Value must be one of: `get`, `upgrade`.
  ╷
1 │ pub_action: bob
  │             ^^^
  ╵'''),
        );
      });

      test('upgrade', () async {
        final monoConfigContent = toYaml({'pub_action': 'upgrade'});

        await populateConfig(monoConfigContent);

        testGenerateBothConfig(
          printMatcher: _subPkgStandardOutput,
        );

        // TODO: validate GitHub case
        await d.file(travisFileName, travisYamlOutput).validate();
        await d.file(ciScriptPath, ciShellOutput).validate();
      });

      test('get', () async {
        final monoConfigContent = toYaml({'pub_action': 'get'});

        await populateConfig(monoConfigContent);

        testGenerateBothConfig(
          printMatcher: _subPkgStandardOutput,
        );

        // TODO: validate GitHub case
        await d.file(travisFileName, travisYamlOutput).validate();
        await d.file(ciScriptPath, contains(r'''
  pub get --no-precompile || EXIT_CODE=$?

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo -e "\033[31mPKG: ${PKG}; 'pub get' - FAILED  (${EXIT_CODE})\033[0m"
    FAILURES+=("${PKG}; 'pub get'")
  else
''')).validate();
      });
    });

    group('pretty_ansi', () {
      test('value must be bool', () async {
        final monoConfigContent = toYaml({'pretty_ansi': 'not a bool!'});
        await populateConfig(monoConfigContent);

        expect(
          testGenerateBothConfig,
          throwsAParsedYamlException(r'''
line 1, column 14 of mono_repo.yaml: Unsupported value for "pretty_ansi". Value must be `true` or `false`.
  ╷
1 │ pretty_ansi: "not a bool!"
  │              ^^^^^^^^^^^^^
  ╵'''),
        );
      });

      test('set to false', () async {
        await populateConfig(toYaml({'pretty_ansi': false}));

        testGenerateBothConfig(
          printMatcher: _subPkgStandardOutput,
        );

        // TODO: validate GitHub case
        await d.file(travisFileName, travisYamlOutput).validate();
        await d.file(ciScriptPath, r'''
#!/bin/bash

# Support built in commands on windows out of the box.
function pub() {
  if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    command pub.bat "$@"
  else
    command pub "$@"
  fi
}
function dartfmt() {
  if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    command dartfmt.bat "$@"
  else
    command dartfmt "$@"
  fi
}
function dartanalyzer() {
  if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    command dartanalyzer.bat "$@"
  else
    command dartanalyzer "$@"
  fi
}

if [[ -z ${PKGS} ]]; then
  echo -e 'PKGS environment variable must be set! - TERMINATING JOB'
  exit 64
fi

if [[ "$#" == "0" ]]; then
  echo -e 'At least one task argument must be provided! - TERMINATING JOB'
  exit 64
fi

SUCCESS_COUNT=0
declare -a FAILURES

for PKG in ${PKGS}; do
  echo -e "PKG: ${PKG}"
  EXIT_CODE=0
  pushd "${PKG}" >/dev/null || EXIT_CODE=$?

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo -e "PKG: '${PKG}' does not exist - TERMINATING JOB"
    exit 64
  fi

  pub upgrade --no-precompile || EXIT_CODE=$?

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo -e "PKG: ${PKG}; 'pub upgrade' - FAILED  (${EXIT_CODE})"
    FAILURES+=("${PKG}; 'pub upgrade'")
  else
    for TASK in "$@"; do
      EXIT_CODE=0
      echo
      echo -e "PKG: ${PKG}; TASK: ${TASK}"
      case ${TASK} in
      dartanalyzer)
        echo 'dartanalyzer .'
        dartanalyzer . || EXIT_CODE=$?
        ;;
      dartfmt)
        echo 'dartfmt -n --set-exit-if-changed .'
        dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
        ;;
      test_0)
        echo 'pub run test --platform chrome'
        pub run test --platform chrome || EXIT_CODE=$?
        ;;
      test_1)
        echo 'pub run test --preset travis'
        pub run test --preset travis || EXIT_CODE=$?
        ;;
      *)
        echo -e "Unknown TASK '${TASK}' - TERMINATING JOB"
        exit 64
        ;;
      esac

      if [[ ${EXIT_CODE} -ne 0 ]]; then
        echo -e "PKG: ${PKG}; TASK: ${TASK} - FAILED (${EXIT_CODE})"
        FAILURES+=("${PKG}; TASK: ${TASK}")
      else
        echo -e "PKG: ${PKG}; TASK: ${TASK} - SUCCEEDED"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      fi

    done
  fi

  echo
  echo -e "SUCCESS COUNT: ${SUCCESS_COUNT}"

  if [ ${#FAILURES[@]} -ne 0 ]; then
    echo -e "FAILURES: ${#FAILURES[@]}"
    for i in "${FAILURES[@]}"; do
      echo -e "  $i"
    done
  fi

  popd >/dev/null || exit 70
  echo
done

if [ ${#FAILURES[@]} -ne 0 ]; then
  exit 1
fi
''').validate();
      });
    });

    group('self_validate', () {
      test('value must be bool or string', () async {
        final monoConfigContent = toYaml({'self_validate': 42});
        await populateConfig(monoConfigContent);

        expect(
          testGenerateBothConfig,
          throwsAParsedYamlException(r'''
line 1, column 16 of mono_repo.yaml: Unsupported value for "self_validate". Value must be `true`, `false`, or a stage name.
  ╷
1 │ self_validate: 42
  │                ^^
  ╵'''),
        );
      });

      test('set to `true`', () async {
        final monoConfigContent = toYaml({'self_validate': true});

        await populateConfig(monoConfigContent);

        testGenerateBothConfig(
          printMatcher: _subPkgStandardOutput,
        );

        // TODO: validate GitHub case
        await d
            .file(
                travisFileName,
                stringContainsInOrder([
                  '''
language: dart

jobs:
  include:
    - stage: mono_repo_self_validate
      name: mono_repo self validate
      os: linux
      script: "pub global activate mono_repo $packageVersion && pub global run mono_repo generate --validate"
''',
                  r'''
stages:
  - mono_repo_self_validate
  - analyze
  - unit_test

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - $HOME/.pub-cache
'''
                ]))
            .validate();
        await d.file(ciScriptPath, ciShellOutput).validate();
      });

      test('set to a stage name', () async {
        final monoConfigContent = toYaml({'self_validate': 'analyze'});

        await populateConfig(monoConfigContent);

        testGenerateBothConfig(
          printMatcher: _subPkgStandardOutput,
        );

        // TODO: validate GitHub case
        await d
            .file(
                travisFileName,
                stringContainsInOrder([
                  '''
jobs:
  include:
    - stage: analyze
      name: mono_repo self validate
      os: linux
      script: "pub global activate mono_repo $packageVersion && pub global run mono_repo generate --validate"
    - stage: analyze
''',
                  r'''
stages:
  - analyze
  - unit_test

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - $HOME/.pub-cache
'''
                ]))
            .validate();
        await d.file(ciScriptPath, ciShellOutput).validate();
      });
    });
  });
}

String get _subPkgStandardOutput => '''
package:sub_pkg
$_writeScriptOutput''';

String get _writeScriptOutput => '''
Wrote `${p.join(d.sandbox, travisFileName)}`.
Wrote `${p.join(d.sandbox, githubActionYamlPath)}`.
$ciScriptPathMessage''';
