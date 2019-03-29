// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:mono_repo/src/package_config.dart';
import 'package:mono_repo/src/yaml.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

void main() {
  test('no package', () async {
    await d.dir('sub_pkg').create();

    expect(
        testGenerateTravisConfig,
        throwsUserExceptionWith(
            'No packages found.',
            'Each target package directory must contain a '
            '`mono_pkg.yaml` file.'));
  });

  test('$monoPkgFileName with non-Map contents', () async {
    await d.dir('sub_pkg', [
      d.file('mono_pkg.yaml', 'bob'),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
        testGenerateTravisConfig,
        throwsUserExceptionWith(
            'The contents of `sub_pkg/mono_pkg.yaml` must be a Map.', isNull));
  });

  test('empty $monoPkgFileName file', () async {
    await d.dir('sub_pkg', [
      d.file('mono_pkg.yaml', '# just a comment!'),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
        testGenerateTravisConfig,
        throwsUserExceptionWith(
            'No entries created. Check your nested `$monoPkgFileName` files.',
            isNull));
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
        throwsUserExceptionWith(
            'Tasks with fancy configuration are not supported. '
            'See `sub_pkg/$monoPkgFileName`.',
            isNull));
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
            'Rename to "mono_pkg.yaml".'));
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
        testGenerateTravisConfig,
        throwsUserExceptionWith(
            'Not all packages agree on `stages` ordering, found a cycle '
            'between the following stages: [analyze, format]',
            isNull));
  });

  test('complete travis.yml file', () async {
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, testConfig2),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
        testGenerateTravisConfig,
        prints(stringContainsInOrder([
          'package:sub_pkg',
          'Make sure to mark `./tool/travis.sh` as executable.'
        ])));

    await d.file(travisFileName, _config2Yaml).validate();
    await d.file(travisShPath, _config2Shell).validate();
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

    expect(
        testGenerateTravisConfig,
        prints(stringContainsInOrder([
          'package:pkg_a',
          'package:pkg_b',
          'Make sure to mark `./tool/travis.sh` as executable.'
        ])));

    await d.file(travisFileName, r'''
# Created with package:mono_repo v1.2.3
language: dart

jobs:
  include:
    - stage: format
      name: "SDK: stable; PKGS: pkg_a; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: stable
      env: PKGS="pkg_a"
      script: ./tool/travis.sh dartfmt
    - stage: format
      name: "SDK: dev; PKGS: pkg_a; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: dev
      env: PKGS="pkg_a"
      script: ./tool/travis.sh dartfmt
    - stage: format
      name: "SDK: dev; PKGS: pkg_b; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: dev
      env: PKGS="pkg_b"
      script: ./tool/travis.sh dartfmt

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

    await d.file(travisShPath, r'''
#!/bin/bash
# Created with package:mono_repo v1.2.3

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
  pub upgrade --no-precompile || exit $?

  for TASK in "$@"; do
    case ${TASK} in
    dartfmt) echo
      echo -e '\033[1mTASK: dartfmt\033[22m'
      echo -e 'dartfmt -n --set-exit-if-changed .'
      dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
      ;;
    *) echo -e "\033[31mNot expecting TASK '${TASK}'. Error!\033[0m"
      EXIT_CODE=1
      ;;
    esac
  done

  popd
done

exit ${EXIT_CODE}
''').validate();
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
        throwsUserExceptionWith(
          'Error parsing pkg_a/mono_pkg.yaml',
          contains('"dart" is missing.'),
        ));
  });

  test('top-level `dart` key value is no-op with group overrides', () async {
    await d.dir('pkg_a', [
      d.file(monoPkgFileName, r'''
dart:
- unneeded

stages:
- analyzer_and_format:
  - group:
    - dartfmt
    - dartanalyzer: --fatal-warnings --fatal-infos .
    dart: [dev]
  - group:
    - dartfmt
    - dartanalyzer: --fatal-warnings .
    dart: [2.1.1]
'''),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    expect(
        testGenerateTravisConfig,
        prints(stringContainsInOrder([
          'package:pkg_a',
          '`dart` values (unneeded) are not used and can be removed.',
          'Make sure to mark `./tool/travis.sh` as executable.'
        ])));

    await d.file(travisFileName, r'''
# Created with package:mono_repo v1.2.3
language: dart

jobs:
  include:
    - stage: analyzer_and_format
      name: "SDK: dev; PKGS: pkg_a; TASKS: [`dartfmt -n --set-exit-if-changed .`, `dartanalyzer --fatal-warnings --fatal-infos .`]"
      dart: dev
      env: PKGS="pkg_a"
      script: ./tool/travis.sh dartfmt dartanalyzer_0
    - stage: analyzer_and_format
      name: "SDK: 2.1.1; PKGS: pkg_a; TASKS: [`dartfmt -n --set-exit-if-changed .`, `dartanalyzer --fatal-warnings .`]"
      dart: "2.1.1"
      env: PKGS="pkg_a"
      script: ./tool/travis.sh dartfmt dartanalyzer_1

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
    await d.file(travisShPath, r'''
#!/bin/bash
# Created with package:mono_repo v1.2.3

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
  pub upgrade --no-precompile || exit $?

  for TASK in "$@"; do
    case ${TASK} in
    dartanalyzer_0) echo
      echo -e '\033[1mTASK: dartanalyzer_0\033[22m'
      echo -e 'dartanalyzer --fatal-warnings --fatal-infos .'
      dartanalyzer --fatal-warnings --fatal-infos . || EXIT_CODE=$?
      ;;
    dartanalyzer_1) echo
      echo -e '\033[1mTASK: dartanalyzer_1\033[22m'
      echo -e 'dartanalyzer --fatal-warnings .'
      dartanalyzer --fatal-warnings . || EXIT_CODE=$?
      ;;
    dartfmt) echo
      echo -e '\033[1mTASK: dartfmt\033[22m'
      echo -e 'dartfmt -n --set-exit-if-changed .'
      dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
      ;;
    *) echo -e "\033[31mNot expecting TASK '${TASK}'. Error!\033[0m"
      EXIT_CODE=1
      ;;
    esac
  done

  popd
done

exit ${EXIT_CODE}
''').validate();
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

    Future validConfig(
        String monoRepoContent, Object expectedTravisContent) async {
      await populateConfig(monoRepoContent);

      await d.nothing(travisShPath).validate();

      expect(
          testGenerateTravisConfig,
          prints(stringContainsInOrder([
            'package:sub_pkg',
            'Make sure to mark `./tool/travis.sh` as executable.'
          ])));

      await d.file(travisFileName, expectedTravisContent).validate();
      await d.file(travisShPath, _config2Shell).validate();
    }

    test('empty travis.yml file', () async {
      await validConfig('', _config2Yaml);
    });

    test('pkg:build integration travis.yml file', () async {
      await validConfig(r'''
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
''', contains(r'''
# Created with package:mono_repo v1.2.3
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
'''));
    });

    test('only supports a travis key', () async {
      var monoConfigContent = toYaml({
        'other': {'stages': 5}
      });
      await populateConfig(monoConfigContent);
      expect(
          testGenerateTravisConfig,
          throwsUserExceptionWith(
              'Error parsing mono_repo.yaml',
              startsWith('line 1, column 1 of mono_repo.yaml: '
                  'Only `travis` key is supported.')));
    });

    group('stages', () {
      test('must be a list', () async {
        var monoConfigContent = toYaml({
          'travis': {'stages': 5}
        });
        await populateConfig(monoConfigContent);
        expect(
            testGenerateTravisConfig,
            throwsUserExceptionWith(
                'Error parsing mono_repo.yaml',
                startsWith('line 2, column 3 of mono_repo.yaml: '
                    '`stages` must be an array.')));
      });

      test('must be map items', () async {
        var monoConfigContent = toYaml({
          'travis': {
            'stages': [5]
          }
        });
        await populateConfig(monoConfigContent);
        expect(
            testGenerateTravisConfig,
            throwsUserExceptionWith(
                'Error parsing mono_repo.yaml',
                startsWith('line 2, column 3 of mono_repo.yaml: '
                    'All values must be Map instances.')));
      });

      test('map item must be exactly name + if – no less', () async {
        var monoConfigContent = toYaml({
          'travis': {
            'stages': [
              {'name': 'bob'}
            ]
          }
        });
        await populateConfig(monoConfigContent);
        expect(
            testGenerateTravisConfig,
            throwsUserExceptionWith(
                'Error parsing mono_repo.yaml',
                startsWith('line 3, column 7 of mono_repo.yaml: '
                    'Required keys are missing: if.')));
      });

      test('map item must be exactly name + if – no more', () async {
        var monoConfigContent = toYaml({
          'travis': {
            'stages': [
              {'name': 'bob', 'if': 'thing', 'bob': 'other'}
            ]
          }
        });
        await populateConfig(monoConfigContent);
        expect(
            testGenerateTravisConfig,
            throwsUserExceptionWith(
                'Error parsing mono_repo.yaml',
                startsWith(
                    'Unrecognized keys: [bob]; supported keys: [name, if]')));
      });

      test('cannot have duplicate names', () async {
        var monoConfigContent = toYaml({
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
            throwsUserExceptionWith(
                'Error parsing mono_repo.yaml',
                startsWith('line 2, column 3 of mono_repo.yaml: '
                    '`bob` appears more than once.')));
      });

      test('must match a configured stage from pkg_config', () async {
        var monoConfigContent = toYaml({
          'travis': {
            'stages': [
              {'name': 'bob', 'if': 'if'}
            ]
          }
        });
        await populateConfig(monoConfigContent);
        expect(
            testGenerateTravisConfig,
            throwsUserExceptionWith(
                'Error parsing mono_repo.yaml',
                'Stage `bob` was referenced in `mono_repo.yaml`, but it does '
                'not exist in any `mono_pkg.yaml` files.'));
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
          var monoConfigContent = toYaml({'travis': invalidContent});
          await populateConfig(monoConfigContent);

          expect(
              testGenerateTravisConfig,
              throwsUserExceptionWith(
                  'Error parsing mono_repo.yaml',
                  startsWith('line 1, column 1 of mono_repo.yaml: '
                      '`travis` must be a Map.')));
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
          var invalidContent = Map.fromIterable(invalidValues);
          var monoConfigContent = toYaml({'travis': invalidContent});
          await populateConfig(monoConfigContent);

          expect(
              testGenerateTravisConfig,
              throwsUserExceptionWith(
                  'Error parsing mono_repo.yaml',
                  startsWith('line 2, column 3 of mono_repo.yaml: '
                      'Contains illegal keys: ${invalidValues.join(', ')}')));
        });
      }
    });
  });
}

final _config2Shell = r"""
#!/bin/bash
# Created with package:mono_repo v1.2.3

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
  pub upgrade --no-precompile || exit $?

  for TASK in "$@"; do
    case ${TASK} in
    dartanalyzer) echo
      echo -e '\033[1mTASK: dartanalyzer\033[22m'
      echo -e 'dartanalyzer .'
      dartanalyzer . || EXIT_CODE=$?
      ;;
    dartfmt) echo
      echo -e '\033[1mTASK: dartfmt\033[22m'
      echo -e 'dartfmt -n --set-exit-if-changed .'
      dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
      ;;
    test_00) echo
      echo -e '\033[1mTASK: test_00\033[22m'
      echo -e 'pub run test --platform chrome'
      pub run test --platform chrome || EXIT_CODE=$?
      ;;
    test_01) echo
      echo -e '\033[1mTASK: test_01\033[22m'
      echo -e 'pub run test --preset travis --total-shards 9 --shard-index 0'
      pub run test --preset travis --total-shards 9 --shard-index 0 || EXIT_CODE=$?
      ;;
    test_02) echo
      echo -e '\033[1mTASK: test_02\033[22m'
      echo -e 'pub run test --preset travis --total-shards 9 --shard-index 1'
      pub run test --preset travis --total-shards 9 --shard-index 1 || EXIT_CODE=$?
      ;;
    test_03) echo
      echo -e '\033[1mTASK: test_03\033[22m'
      echo -e 'pub run test --preset travis --total-shards 9 --shard-index 2'
      pub run test --preset travis --total-shards 9 --shard-index 2 || EXIT_CODE=$?
      ;;
    test_04) echo
      echo -e '\033[1mTASK: test_04\033[22m'
      echo -e 'pub run test --preset travis --total-shards 9 --shard-index 3'
      pub run test --preset travis --total-shards 9 --shard-index 3 || EXIT_CODE=$?
      ;;
    test_05) echo
      echo -e '\033[1mTASK: test_05\033[22m'
      echo -e 'pub run test --preset travis --total-shards 9 --shard-index 4'
      pub run test --preset travis --total-shards 9 --shard-index 4 || EXIT_CODE=$?
      ;;
    test_06) echo
      echo -e '\033[1mTASK: test_06\033[22m'
      echo -e 'pub run test --preset travis --total-shards 9 --shard-index 5'
      pub run test --preset travis --total-shards 9 --shard-index 5 || EXIT_CODE=$?
      ;;
    test_07) echo
      echo -e '\033[1mTASK: test_07\033[22m'
      echo -e 'pub run test --preset travis --total-shards 9 --shard-index 6'
      pub run test --preset travis --total-shards 9 --shard-index 6 || EXIT_CODE=$?
      ;;
    test_08) echo
      echo -e '\033[1mTASK: test_08\033[22m'
      echo -e 'pub run test --preset travis --total-shards 9 --shard-index 7'
      pub run test --preset travis --total-shards 9 --shard-index 7 || EXIT_CODE=$?
      ;;
    test_09) echo
      echo -e '\033[1mTASK: test_09\033[22m'
      echo -e 'pub run test --preset travis --total-shards 9 --shard-index 8'
      pub run test --preset travis --total-shards 9 --shard-index 8 || EXIT_CODE=$?
      ;;
    test_10) echo
      echo -e '\033[1mTASK: test_10\033[22m'
      echo -e 'pub run test'
      pub run test || EXIT_CODE=$?
      ;;
    *) echo -e "\033[31mNot expecting TASK '${TASK}'. Error!\033[0m"
      EXIT_CODE=1
      ;;
    esac
  done

  popd
done

exit ${EXIT_CODE}
""";

final _config2Yaml = r'''
# Created with package:mono_repo v1.2.3
language: dart

jobs:
  include:
    - stage: analyze
      name: "SDK: dev; PKGS: sub_pkg; TASKS: [`dartanalyzer .`, `dartfmt -n --set-exit-if-changed .`]"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh dartanalyzer dartfmt
    - stage: analyze
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `dartanalyzer .`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh dartanalyzer
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: chrome tests"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_00
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: chrome tests"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_00
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: chrome tests"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_00
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 0`"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_01
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 0`"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_01
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 0`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_01
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 1`"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_02
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 1`"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_02
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 1`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_02
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 2`"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_03
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 2`"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_03
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 2`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_03
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 3`"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_04
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 3`"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_04
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 3`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_04
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 4`"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_05
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 4`"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_05
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 4`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_05
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 5`"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_06
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 5`"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_06
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 5`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_06
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 6`"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_07
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 6`"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_07
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 6`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_07
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 7`"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_08
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 7`"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_08
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 7`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_08
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 8`"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_09
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 8`"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_09
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `pub run test --preset travis --total-shards 9 --shard-index 8`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_09
    - stage: unit_test
      name: "SDK: dev; PKGS: sub_pkg; TASKS: `pub run test`"
      dart: dev
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_10
    - stage: unit_test
      name: "SDK: stable; PKGS: sub_pkg; TASKS: `pub run test`"
      dart: stable
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_10
    - stage: unit_test
      name: "SDK: 1.23.0; PKGS: sub_pkg; TASKS: `pub run test`"
      dart: "1.23.0"
      env: PKGS="sub_pkg"
      script: ./tool/travis.sh test_10

stages:
  - analyze
  - unit_test

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - "$HOME/.pub-cache"
''';
