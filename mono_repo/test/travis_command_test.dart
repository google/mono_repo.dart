// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:mono_repo/mono_repo.dart';
import 'package:mono_repo/src/commands/travis/travis_shell.dart'
    show windowsBoilerplate;
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

  test('no package', () async {
    await d.dir('sub_pkg').create();

    expect(
      testGenerateTravisConfig,
      throwsUserExceptionWith(
        'No packages found.',
        'Each target package directory must contain a '
            '`mono_pkg.yaml` file.',
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
      testGenerateTravisConfig,
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
      () => testGenerateTravisConfig(
        printMatcher: '''
package:sub_pkg
  `dart` values () are not used and can be removed.
  `os` values () are not used and can be removed.''',
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
      testGenerateTravisConfig,
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
      testGenerateTravisConfig,
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
      () => testGenerateTravisConfig(
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
        () => testGenerateTravisConfig(
          validateOnly: true,
          printMatcher: 'package:sub_pkg',
        ),
        throwsA(isA<UserException>()),
      );
    });

    test('throws if the previous config doesn\'t match', () async {
      await d.file(travisFileName, '').create();
      await d.dir('tool', [
        d.file('travis.sh', ''),
      ]).create();
      expect(
        () => testGenerateTravisConfig(
          validateOnly: true,
          printMatcher: 'package:sub_pkg',
        ),
        throwsA(isA<UserException>()),
      );
    });

    test("doesn't throw if the previous config is up to date", () async {
      testGenerateTravisConfig(
        printMatcher: stringContainsInOrder([
          'package:sub_pkg',
          'Make sure to mark `tool/travis.sh` as executable.'
        ]),
      );

      // Just check that this doesn't throw.
      testGenerateTravisConfig(
        printMatcher: stringContainsInOrder(['package:sub_pkg']),
      );
    });
  });

  test('complete travis.yml file', () async {
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, testConfig2),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    testGenerateTravisConfig(
      printMatcher: stringContainsInOrder([
        'package:sub_pkg',
        'Make sure to mark `tool/travis.sh` as executable.'
      ]),
    );
    await d.file(travisFileName, travisYamlOutput).validate();
    await d.file(travisShPath, travisShellOutput).validate();
  });

  test('complete travis.yml file', () async {
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, testConfig2),
      d.file('pubspec.yaml', '''
name: pkg_name
environment:
  sdk: '>=2.1.0 <3.0.0'
''')
    ]).create();

    testGenerateTravisConfig(
      printMatcher: stringContainsInOrder([
        'package:sub_pkg',
        '  There are jobs defined that are not compatible with the package '
            'SDK constraint (>=2.1.0 <3.0.0): `1.23.0`.',
        'Make sure to mark `tool/travis.sh` as executable.',
      ]),
    );

    await d.file(travisFileName, travisYamlOutput).validate();
    await d.file(travisShPath, travisShellOutput).validate();
  });

  test('using `get` in place of `upgrade`', () async {
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, testConfig2),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    testGenerateTravisConfig(
      useGet: true,
      printMatcher: stringContainsInOrder([
        'The `--use-get` flag is deprecated. Use `pub_action: get` value in '
            '`mono_repo.yaml` instead.',
        'package:sub_pkg',
        'Make sure to mark `tool/travis.sh` as executable.'
      ]),
    );

    // replacement isn't actually how useGet works, but it is a concise test
    await d
        .file(travisShPath, travisShellOutput.replaceAll('upgrade', 'get'))
        .validate();
    await d.file(travisFileName, travisYamlOutput).validate();
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

    testGenerateTravisConfig(
      printMatcher: stringContainsInOrder([
        'package:pkg_a',
        'package:pkg_b',
        'Make sure to mark `tool/travis.sh` as executable.'
      ]),
    );

    await d.file(travisFileName, r'''
language: dart

jobs:
  include:
    - stage: format
      name: "SDK: dev; PKG: pkg_a; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: dev
      os: linux
      env: PKGS="pkg_a"
      script: tool/travis.sh dartfmt
    - stage: format
      name: "SDK: stable; PKG: pkg_a; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: stable
      os: linux
      env: PKGS="pkg_a"
      script: tool/travis.sh dartfmt
    - stage: format
      name: "SDK: dev; PKG: pkg_b; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: dev
      os: linux
      env: PKGS="pkg_b"
      script: tool/travis.sh dartfmt

stages:
  - format

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - "$HOME/.pub-cache"
    - /some_repo_root_dir
    - pkg_a/.dart_tool
    - pkg_b/.dart_tool
''').validate();

    await d
        .file(
            travisShPath,
            '''
#!/bin/bash

$windowsBoilerplate

'''
            r'''
if [[ -z ${PKGS} ]]; then
  echo -e '\033[31mPKGS environment variable must be set!\033[0m'
  exit 1
fi

if [[ "$#" == "0" ]]; then
  echo -e '\033[31mAt least one task argument must be provided!\033[0m'
  exit 1
fi

EXIT_CODE=0

for PKG in ${PKGS}; do
  echo -e "\033[1mPKG: ${PKG}\033[22m"
  pushd "${PKG}" || exit $?

  PUB_EXIT_CODE=0
  pub upgrade --no-precompile || PUB_EXIT_CODE=$?

  if [[ ${PUB_EXIT_CODE} -ne 0 ]]; then
    EXIT_CODE=1
    echo -e '\033[31mpub upgrade failed\033[0m'
    popd
    continue
  fi

  for TASK in "$@"; do
    echo
    echo -e "\033[1mPKG: ${PKG}; TASK: ${TASK}\033[22m"
    case ${TASK} in
    dartfmt)
      echo 'dartfmt -n --set-exit-if-changed .'
      dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
      ;;
    *)
      echo -e "\033[31mNot expecting TASK '${TASK}'. Error!\033[0m"
      EXIT_CODE=1
      ;;
    esac
  done

  popd
done

exit ${EXIT_CODE}
''')
        .validate();
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

    testGenerateTravisConfig(
      printMatcher: stringContainsInOrder([
        'package:pkg_a',
        'package:pkg_b',
        'Make sure to mark `tool/travis.sh` as executable.'
      ]),
    );

    await d.file(travisFileName, r'''
language: dart

jobs:
  include:
    - stage: format
      name: "SDK: dev; PKG: pkg_a; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: dev
      os: linux
      env: PKGS="pkg_a"
      script: tool/travis.sh dartfmt_0
    - stage: format
      name: "SDK: stable; PKG: pkg_a; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: stable
      os: linux
      env: PKGS="pkg_a"
      script: tool/travis.sh dartfmt_0
    - stage: format
      name: "SDK: dev; PKG: pkg_b; TASKS: `dartfmt --dry-run --fix --set-exit-if-changed .`"
      dart: dev
      os: linux
      env: PKGS="pkg_b"
      script: tool/travis.sh dartfmt_1

stages:
  - format

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - "$HOME/.pub-cache"
    - /some_repo_root_dir
    - pkg_a/.dart_tool
    - pkg_b/.dart_tool
''').validate();

    await d
        .file(
            travisShPath,
            '''
#!/bin/bash

$windowsBoilerplate

'''
            r'''
if [[ -z ${PKGS} ]]; then
  echo -e '\033[31mPKGS environment variable must be set!\033[0m'
  exit 1
fi

if [[ "$#" == "0" ]]; then
  echo -e '\033[31mAt least one task argument must be provided!\033[0m'
  exit 1
fi

EXIT_CODE=0

for PKG in ${PKGS}; do
  echo -e "\033[1mPKG: ${PKG}\033[22m"
  pushd "${PKG}" || exit $?

  PUB_EXIT_CODE=0
  pub upgrade --no-precompile || PUB_EXIT_CODE=$?

  if [[ ${PUB_EXIT_CODE} -ne 0 ]]; then
    EXIT_CODE=1
    echo -e '\033[31mpub upgrade failed\033[0m'
    popd
    continue
  fi

  for TASK in "$@"; do
    echo
    echo -e "\033[1mPKG: ${PKG}; TASK: ${TASK}\033[22m"
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
      echo -e "\033[31mNot expecting TASK '${TASK}'. Error!\033[0m"
      EXIT_CODE=1
      ;;
    esac
  done

  popd
done

exit ${EXIT_CODE}
''')
        .validate();
  });

  test('missing `dart` key', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName, r'''
stages:
  - format:
    - dartfmt
'''),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    expect(
      testGenerateTravisConfig,
      throwsAParsedYamlException(
        contains('"dart" is missing.'),
      ),
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
- analyzer_and_format:
  - group:
    - dartfmt
    - dartanalyzer: --fatal-warnings --fatal-infos .
    dart: [dev]
    os: [windows]
  - group:
    - dartfmt
    - dartanalyzer: --fatal-warnings .
    dart: [2.1.1]
    os: [osx]
'''),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    testGenerateTravisConfig(
      printMatcher: stringContainsInOrder([
        'package:pkg_a',
        '`dart` values (unneeded) are not used and can be removed.',
        'Make sure to mark `tool/travis.sh` as executable.'
      ]),
    );

    await d.file(travisFileName, r'''
language: dart

jobs:
  include:
    - stage: analyzer_and_format
      name: "SDK: dev; PKG: pkg_a; TASKS: [`dartfmt -n --set-exit-if-changed .`, `dartanalyzer --fatal-warnings --fatal-infos .`]"
      dart: dev
      os: windows
      env: PKGS="pkg_a"
      script: tool/travis.sh dartfmt dartanalyzer_0
    - stage: analyzer_and_format
      name: "SDK: 2.1.1; PKG: pkg_a; TASKS: [`dartfmt -n --set-exit-if-changed .`, `dartanalyzer --fatal-warnings .`]"
      dart: "2.1.1"
      os: osx
      env: PKGS="pkg_a"
      script: tool/travis.sh dartfmt dartanalyzer_1

stages:
  - analyzer_and_format

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - "$HOME/.pub-cache"
''').validate();
    await d
        .file(
            travisShPath,
            '''
#!/bin/bash

$windowsBoilerplate

'''
            r'''
if [[ -z ${PKGS} ]]; then
  echo -e '\033[31mPKGS environment variable must be set!\033[0m'
  exit 1
fi

if [[ "$#" == "0" ]]; then
  echo -e '\033[31mAt least one task argument must be provided!\033[0m'
  exit 1
fi

EXIT_CODE=0

for PKG in ${PKGS}; do
  echo -e "\033[1mPKG: ${PKG}\033[22m"
  pushd "${PKG}" || exit $?

  PUB_EXIT_CODE=0
  pub upgrade --no-precompile || PUB_EXIT_CODE=$?

  if [[ ${PUB_EXIT_CODE} -ne 0 ]]; then
    EXIT_CODE=1
    echo -e '\033[31mpub upgrade failed\033[0m'
    popd
    continue
  fi

  for TASK in "$@"; do
    echo
    echo -e "\033[1mPKG: ${PKG}; TASK: ${TASK}\033[22m"
    case ${TASK} in
    dartanalyzer_0)
      echo 'dartanalyzer --fatal-warnings --fatal-infos .'
      dartanalyzer --fatal-warnings --fatal-infos . || EXIT_CODE=$?
      ;;
    dartanalyzer_1)
      echo 'dartanalyzer --fatal-warnings .'
      dartanalyzer --fatal-warnings . || EXIT_CODE=$?
      ;;
    dartfmt)
      echo 'dartfmt -n --set-exit-if-changed .'
      dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
      ;;
    *)
      echo -e "\033[31mNot expecting TASK '${TASK}'. Error!\033[0m"
      EXIT_CODE=1
      ;;
    esac
  done

  popd
done

exit ${EXIT_CODE}
''')
        .validate();
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
        testGenerateTravisConfig,
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
      testGenerateTravisConfig,
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

    testGenerateTravisConfig(printMatcher: isNotEmpty);

    await d
        .file(
          travisShPath,
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

      await d.nothing(travisFileName).validate();
      await d.nothing(travisShPath).validate();
      await d.nothing(travisSelfValidateScriptPath).validate();

      testGenerateTravisConfig(
        printMatcher: stringContainsInOrder([
          'package:sub_pkg',
          'Make sure to mark `tool/travis.sh` as executable.',
          '  chmod +x tool/travis.sh'
        ]),
      );

      await d.file(travisFileName, expectedTravisContent).validate();
      await d.file(travisShPath, travisShellOutput).validate();
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
        testGenerateTravisConfig,
        throwsAParsedYamlException(r'''
line 2, column 3 of mono_repo.yaml: Unsupported value for "other". Only `pub_action`, `merge_stages`, `self_validate`, `travis` keys are supported.
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
          printMatcher: stringContainsInOrder([
            'package:sub_pkg1',
            'package:sub_pkg2',
            'Make sure to mark `tool/travis.sh` as executable.'
          ]),
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
          printMatcher: stringContainsInOrder([
            'package:sub_pkg1',
            'package:sub_pkg2',
          ]),
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

    group('merge_stages', () {
      test('must be a list', () async {
        final monoConfigContent = toYaml({
          'merge_stages': {'stages': 5}
        });
        await populateConfig(monoConfigContent);
        expect(
          testGenerateTravisConfig,
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
          testGenerateTravisConfig,
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
          () => testGenerateTravisConfig(printMatcher: 'package:sub_pkg'),
          throwsUserExceptionWith(
            'Error parsing mono_repo.yaml',
            'One or more stage was referenced in `mono_repo.yaml` that do not '
                'exist in any `mono_pkg.yaml` files: `bob`.',
          ),
        );
      });
    });

    group('invalid travis value type', () {
      for (var invalidContent in [
        true,
        5,
        'string',
        ['array']
      ]) {
        test(invalidContent.runtimeType.toString(), () async {
          final monoConfigContent = toYaml({'travis': invalidContent});
          await populateConfig(monoConfigContent);

          expect(
            testGenerateTravisConfig,
            throwsAParsedYamlException(
              contains(
                  'Unsupported value for "travis". `travis` must be a Map.'),
            ),
          );
        });
      }
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

    group('pub_action', () {
      test('value must be a String', () async {
        final monoConfigContent = toYaml({'pub_action': 42});
        await populateConfig(monoConfigContent);

        expect(
          testGenerateTravisConfig,
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
          testGenerateTravisConfig,
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

        testGenerateTravisConfig(
          printMatcher: stringContainsInOrder(
            [
              'package:sub_pkg',
              'Make sure to mark `tool/travis.sh` as executable.',
              '  chmod +x tool/travis.sh',
            ],
          ),
        );

        await d.file(travisFileName, travisYamlOutput).validate();
        await d.file(travisShPath, travisShellOutput).validate();
      });

      test('get', () async {
        final monoConfigContent = toYaml({'pub_action': 'get'});

        await populateConfig(monoConfigContent);

        testGenerateTravisConfig(
          printMatcher: stringContainsInOrder(
            [
              'package:sub_pkg',
              'Make sure to mark `tool/travis.sh` as executable.',
              '  chmod +x tool/travis.sh',
            ],
          ),
        );

        await d.file(travisFileName, travisYamlOutput).validate();
        await d.file(travisShPath, contains(r'''
  pub get --no-precompile || PUB_EXIT_CODE=$?

  if [[ ${PUB_EXIT_CODE} -ne 0 ]]; then
    EXIT_CODE=1
    echo -e '\033[31mpub get failed\033[0m'
    popd
    continue
  fi
''')).validate();
      });
    });

    group('self_validate', () {
      test('value must be bool', () async {
        final monoConfigContent = toYaml({'self_validate': 'not a bool!'});
        await populateConfig(monoConfigContent);

        expect(
          testGenerateTravisConfig,
          throwsAParsedYamlException(r'''
line 1, column 16 of mono_repo.yaml: Unsupported value for "self_validate". Value must be `true` or `false`.
  ╷
1 │ self_validate: "not a bool!"
  │                ^^^^^^^^^^^^^
  ╵'''),
        );
      });

      test('used with a valid configuration', () async {
        final monoConfigContent = toYaml({'self_validate': true});

        await populateConfig(monoConfigContent);

        testGenerateTravisConfig(
          printMatcher: stringContainsInOrder(
            [
              'package:sub_pkg',
              'Make sure to mark `tool/travis.sh` as executable.',
              '  chmod +x tool/travis.sh',
              'Make sure to mark `tool/mono_repo_self_validate.sh` as executable.',
              '  chmod +x tool/mono_repo_self_validate.sh',
            ],
          ),
        );

        await d
            .file(
                travisFileName,
                stringContainsInOrder([
                  r'''
language: dart

jobs:
  include:
    - stage: mono_repo_self_validate
      name: mono_repo self validate
      os: linux
      script: tool/mono_repo_self_validate.sh
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
    - "$HOME/.pub-cache"
'''
                ]))
            .validate();
        await d.file(travisShPath, travisShellOutput).validate();
        await d
            .file(travisSelfValidateScriptPath, contains('travis --validate'))
            .validate();
      });
    });
  });
}
