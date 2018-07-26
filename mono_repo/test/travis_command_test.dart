// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:io/ansi.dart';
import 'package:mono_repo/src/commands/travis.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:mono_repo/src/mono_config.dart';

import 'shared.dart';

void main() {
  group('safeEcho', () {
    var values = {
      'hello': "echo -e 'hello'",
      "single-quotes 'inside' the string":
          "echo -e 'single-quotes '\\''inside'\\'' the string'",
      "'single quotes' at the beginning 'middle' and at the 'end'":
          "echo -e ''\\''single quotes'\\'' at the beginning '\\''middle'\\'' and at the '\\''end'\\'''",
      "Repeated single quotes ''' in the '' middle":
          "echo -e 'Repeated single quotes '\\'''\\'''\\'' in the '\\'''\\'' middle'",
    };

    values.forEach((input, expected) {
      test(input, () {
        expect(safeEcho(false, null, input), expected);
      });
    });
  });

  test('no package', () async {
    await d.dir('sub_pkg').create();

    expect(() => generateTravisConfig(rootDirectory: d.sandbox),
        throwsUserExceptionWith('No nested packages found.'));
  });

  test('no $monoFileName file', () async {
    await d.dir('sub_pkg', [
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
        () => generateTravisConfig(rootDirectory: d.sandbox),
        throwsUserExceptionWith(
            'No entries created. Check your nested `$monoFileName` files.'));
  });

  test('fails with unsupported configuration', () async {
    await d.dir('sub_pkg', [
      d.file(monoFileName, testConfig1),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
        () => generateTravisConfig(rootDirectory: d.sandbox),
        throwsUserExceptionWith(
            'Tasks with fancy configuration are not supported. '
            'See `sub_pkg/$monoFileName`.'));
  });

  test('conflicting stage orders are not allowed', () async {
    await d.dir('pkg_a', [
      d.file(monoFileName, r'''
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
      d.file(monoFileName, r'''
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
        () async => await overrideAnsiOutput(false, () async {
              await generateTravisConfig(rootDirectory: d.sandbox);
            }),
        throwsUserExceptionWith(
            'Not all packages agree on `stages` ordering, found a cycle '
            'between the following stages: [analyze, format]'));
  });

  test('complete travis.yml file', () async {
    await d.dir('sub_pkg', [
      d.file(monoFileName, testConfig2),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    await overrideAnsiOutput(false, () async {
      await generateTravisConfig(rootDirectory: d.sandbox);
    });

    await d.file(travisFileName, _config2Yaml).validate();
    await d.file(travisShPath, _config2Shell).validate();
  });

  test('two flavors of dartfmt', () async {
    await d.dir('pkg_a', [
      d.file(monoFileName, r'''
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
      d.file(monoFileName, r'''
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

    await overrideAnsiOutput(false, () async {
      await generateTravisConfig(rootDirectory: d.sandbox);
    });

    await d.file(travisFileName, r'''
# Created with https://github.com/dart-lang/mono_repo
language: dart

jobs:
  include:
    - stage: format
      name: "SDK: stable - DIR: pkg_a - TASKS: dartfmt -n --set-exit-if-changed ."
      script: ./tool/travis.sh dartfmt
      env: PKG="pkg_a"
      dart: stable
    - stage: format
      name: "SDK: dev - DIR: pkg_a - TASKS: dartfmt -n --set-exit-if-changed ."
      script: ./tool/travis.sh dartfmt
      env: PKG="pkg_a"
      dart: dev
    - stage: format
      name: "SDK: dev - DIR: pkg_b - TASKS: dartfmt -n --set-exit-if-changed ."
      script: ./tool/travis.sh dartfmt
      env: PKG="pkg_b"
      dart: dev

stages:
  - format

# Only building master means that we don't run two builds for each pull request.
branches:
  only: [master]

cache:
  directories:
    - $HOME/.pub-cache
    - /some_repo_root_dir
    - pkg_a/.dart_tool
    - pkg_b/.dart_tool
''').validate();

    await d.file(travisShPath, r'''
#!/bin/bash
# Created with https://github.com/dart-lang/mono_repo

if [ -z "$PKG" ]; then
  echo -e '\033[31mPKG environment variable must be set!\033[0m'
  exit 1
fi

if [ "$#" == "0" ]; then
  echo -e '\033[31mAt least one task argument must be provided!\033[0m'
  exit 1
fi

pushd $PKG
pub upgrade || exit $?

EXIT_CODE=0

while (( "$#" )); do
  TASK=$1
  case $TASK in
  dartfmt) echo
    echo -e '\033[1mTASK: dartfmt\033[22m'
    echo -e 'dartfmt -n --set-exit-if-changed .'
    dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
    ;;
  *) echo -e "\033[31mNot expecting TASK '${TASK}'. Error!\033[0m"
    EXIT_CODE=1
    ;;
  esac

  shift
done

exit $EXIT_CODE
''').validate();
  });
}

final _config2Shell = r"""
#!/bin/bash
# Created with https://github.com/dart-lang/mono_repo

if [ -z "$PKG" ]; then
  echo -e '\033[31mPKG environment variable must be set!\033[0m'
  exit 1
fi

if [ "$#" == "0" ]; then
  echo -e '\033[31mAt least one task argument must be provided!\033[0m'
  exit 1
fi

pushd $PKG
pub upgrade || exit $?

EXIT_CODE=0

while (( "$#" )); do
  TASK=$1
  case $TASK in
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

  shift
done

exit $EXIT_CODE
""";

final _config2Yaml = r'''
# Created with https://github.com/dart-lang/mono_repo
language: dart

jobs:
  include:
    - stage: analyze
      name: "SDK: dev - DIR: sub_pkg - TASKS: [dartanalyzer ., dartfmt -n --set-exit-if-changed .]"
      script: ./tool/travis.sh dartanalyzer dartfmt
      env: PKG="sub_pkg"
      dart: dev
    - stage: analyze
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: dartanalyzer ."
      script: ./tool/travis.sh dartanalyzer
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: chrome tests"
      script: ./tool/travis.sh test_00
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: chrome tests"
      script: ./tool/travis.sh test_00
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: chrome tests"
      script: ./tool/travis.sh test_00
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 0"
      script: ./tool/travis.sh test_01
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 0"
      script: ./tool/travis.sh test_01
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 0"
      script: ./tool/travis.sh test_01
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 1"
      script: ./tool/travis.sh test_02
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 1"
      script: ./tool/travis.sh test_02
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 1"
      script: ./tool/travis.sh test_02
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 2"
      script: ./tool/travis.sh test_03
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 2"
      script: ./tool/travis.sh test_03
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 2"
      script: ./tool/travis.sh test_03
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 3"
      script: ./tool/travis.sh test_04
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 3"
      script: ./tool/travis.sh test_04
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 3"
      script: ./tool/travis.sh test_04
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 4"
      script: ./tool/travis.sh test_05
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 4"
      script: ./tool/travis.sh test_05
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 4"
      script: ./tool/travis.sh test_05
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 5"
      script: ./tool/travis.sh test_06
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 5"
      script: ./tool/travis.sh test_06
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 5"
      script: ./tool/travis.sh test_06
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 6"
      script: ./tool/travis.sh test_07
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 6"
      script: ./tool/travis.sh test_07
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 6"
      script: ./tool/travis.sh test_07
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 7"
      script: ./tool/travis.sh test_08
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 7"
      script: ./tool/travis.sh test_08
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 7"
      script: ./tool/travis.sh test_08
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 8"
      script: ./tool/travis.sh test_09
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 8"
      script: ./tool/travis.sh test_09
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: pub run test --preset travis --total-shards 9 --shard-index 8"
      script: ./tool/travis.sh test_09
      env: PKG="sub_pkg"
      dart: 1.23.0
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test"
      script: ./tool/travis.sh test_10
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: stable - DIR: sub_pkg - TASKS: pub run test"
      script: ./tool/travis.sh test_10
      env: PKG="sub_pkg"
      dart: stable
    - stage: unit_test
      name: "SDK: 1.23.0 - DIR: sub_pkg - TASKS: pub run test"
      script: ./tool/travis.sh test_10
      env: PKG="sub_pkg"
      dart: 1.23.0

stages:
  - analyze
  - unit_test

# Only building master means that we don't run two builds for each pull request.
branches:
  only: [master]

cache:
  directories:
    - $HOME/.pub-cache
''';
