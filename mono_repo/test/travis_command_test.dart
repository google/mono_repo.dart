// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:io/ansi.dart';
import 'package:mono_repo/src/commands/travis.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

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

  test('no travis.yml file', () async {
    await d.dir('sub_pkg', [
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
        () => generateTravisConfig(rootDirectory: d.sandbox),
        throwsUserExceptionWith(
            'No entries created. Check your nested `.travis.yml` files.'));
  });

  test('fails with unsupported configuration', () async {
    await d.dir('sub_pkg', [
      d.file('.travis.yml', testConfig1),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
        () => generateTravisConfig(rootDirectory: d.sandbox),
        throwsUserExceptionWith(
            'Tasks with fancy configuration are not supported. '
            'See `sub_pkg/.travis.yml`.'));
  });

  test('complex travis.yml file', () async {
    await d.dir('sub_pkg', [
      d.file('.travis.yml', testConfig2),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    await overrideAnsiOutput(false, () async {
      await generateTravisConfig(rootDirectory: d.sandbox);
    });

    await d.file('.travis.yml', _config2Yaml).validate();
    await d.file('tool/travis.sh', _config2Shell).validate();
  });

  test('two flavors of dartfmt', () async {
    await d.dir('pkg_a', [
      d.file('.travis.yml', r'''language: dart
dart:
 - stable
 - dev

dart_task:
 - dartfmt

matrix:
  allow_failures:
    - dart: dev
      dart_task: dartfmt
'''),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    await d.dir('pkg_b', [
      d.file('.travis.yml', r'''language: dart
dart:
 - dev

dart_task:
 - dartfmt: sdk
'''),
      d.file('pubspec.yaml', '''
name: pkg_b
      ''')
    ]).create();

    await overrideAnsiOutput(false, () async {
      await generateTravisConfig(rootDirectory: d.sandbox);
    });

    await d.file(
        '.travis.yml', r'''# Created with https://github.com/dart-lang/mono_repo
language: dart

dart:
  - dev
  - stable

env:
  - PKG=pkg_a TASK=dartfmt
  - PKG=pkg_b TASK=dartfmt

matrix:
  exclude:
    - dart: stable
      env: PKG=pkg_b TASK=dartfmt
  allow_failures:
    - dart: dev
      env: PKG=pkg_a TASK=dartfmt

script: ./tool/travis.sh

# Only building master means that we don't run two builds for each pull request.
branches:
  only: [master]

cache:
 directories:
   - $HOME/.pub-cache
''').validate();

    await d.file('tool/travis.sh', r'''#!/bin/bash
# Created with https://github.com/dart-lang/mono_repo

# Fast fail the script on failures.
set -e

if [ -z "$PKG" ]; then
  echo -e 'PKG environment variable must be set!'
  exit 1
elif [ -z "$TASK" ]; then
  echo -e 'TASK environment variable must be set!'
  exit 1
fi

pushd $PKG
pub upgrade

case $TASK in
dartfmt) echo
  echo -e 'TASK: dartfmt'
  echo -e 'dartfmt -n --set-exit-if-changed .'
  dartfmt -n --set-exit-if-changed .
  ;;
*) echo -e "Not expecting TASK '${TASK}'. Error!"
  exit 1
  ;;
esac
''').validate();
  });
}

final _config2Shell = r'''#!/bin/bash
# Created with https://github.com/dart-lang/mono_repo

# Fast fail the script on failures.
set -e

if [ -z "$PKG" ]; then
  echo -e 'PKG environment variable must be set!'
  exit 1
elif [ -z "$TASK" ]; then
  echo -e 'TASK environment variable must be set!'
  exit 1
fi

pushd $PKG
pub upgrade

case $PKG in
sub_pkg) echo
  echo -e 'sub_pkg: before_script'
  tool/build.sh
  ;;
esac

case $TASK in
dartanalyzer) echo
  echo -e 'TASK: dartanalyzer'
  echo -e 'dartanalyzer .'
  dartanalyzer .
  ;;
dartfmt) echo
  echo -e 'TASK: dartfmt'
  echo -e 'dartfmt -n --set-exit-if-changed .'
  dartfmt -n --set-exit-if-changed .
  ;;
test_00) echo
  echo -e 'TASK: test_00'
  echo -e 'pub run test --platform dartium'
  pub run test --platform dartium
  ;;
test_01) echo
  echo -e 'TASK: test_01'
  echo -e 'pub run test --preset travis --total-shards 9 --shard-index 0'
  pub run test --preset travis --total-shards 9 --shard-index 0
  ;;
test_02) echo
  echo -e 'TASK: test_02'
  echo -e 'pub run test --preset travis --total-shards 9 --shard-index 1'
  pub run test --preset travis --total-shards 9 --shard-index 1
  ;;
test_03) echo
  echo -e 'TASK: test_03'
  echo -e 'pub run test --preset travis --total-shards 9 --shard-index 2'
  pub run test --preset travis --total-shards 9 --shard-index 2
  ;;
test_04) echo
  echo -e 'TASK: test_04'
  echo -e 'pub run test --preset travis --total-shards 9 --shard-index 3'
  pub run test --preset travis --total-shards 9 --shard-index 3
  ;;
test_05) echo
  echo -e 'TASK: test_05'
  echo -e 'pub run test --preset travis --total-shards 9 --shard-index 4'
  pub run test --preset travis --total-shards 9 --shard-index 4
  ;;
test_06) echo
  echo -e 'TASK: test_06'
  echo -e 'pub run test --preset travis --total-shards 9 --shard-index 5'
  pub run test --preset travis --total-shards 9 --shard-index 5
  ;;
test_07) echo
  echo -e 'TASK: test_07'
  echo -e 'pub run test --preset travis --total-shards 9 --shard-index 6'
  pub run test --preset travis --total-shards 9 --shard-index 6
  ;;
test_08) echo
  echo -e 'TASK: test_08'
  echo -e 'pub run test --preset travis --total-shards 9 --shard-index 7'
  pub run test --preset travis --total-shards 9 --shard-index 7
  ;;
test_09) echo
  echo -e 'TASK: test_09'
  echo -e 'pub run test --preset travis --total-shards 9 --shard-index 8'
  pub run test --preset travis --total-shards 9 --shard-index 8
  ;;
test_10) echo
  echo -e 'TASK: test_10'
  echo -e 'pub run test'
  pub run test
  ;;
*) echo -e "Not expecting TASK '${TASK}'. Error!"
  exit 1
  ;;
esac
''';

final _config2Yaml = r'''# Created with https://github.com/dart-lang/mono_repo
language: dart

dart:
  - 1.23.0
  - dev
  - stable

env:
  - PKG=sub_pkg TASK=dartanalyzer
  - PKG=sub_pkg TASK=dartfmt
  - PKG=sub_pkg TASK=test_00
  - PKG=sub_pkg TASK=test_01
  - PKG=sub_pkg TASK=test_02
  - PKG=sub_pkg TASK=test_03
  - PKG=sub_pkg TASK=test_04
  - PKG=sub_pkg TASK=test_05
  - PKG=sub_pkg TASK=test_06
  - PKG=sub_pkg TASK=test_07
  - PKG=sub_pkg TASK=test_08
  - PKG=sub_pkg TASK=test_09
  - PKG=sub_pkg TASK=test_10

matrix:
  exclude:
    - dart: stable
      env: PKG=sub_pkg TASK=dartanalyzer
    - dart: 1.23.0
      env: PKG=sub_pkg TASK=dartfmt
    - dart: stable
      env: PKG=sub_pkg TASK=dartfmt
  allow_failures:
    - dart: dev
      env: PKG=sub_pkg TASK=dartfmt

script: ./tool/travis.sh

# Only building master means that we don't run two builds for each pull request.
branches:
  only: [master]

cache:
 directories:
   - $HOME/.pub-cache
''';
