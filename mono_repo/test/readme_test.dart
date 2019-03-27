// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:mono_repo/src/package_config.dart';

import 'shared.dart';

// TODO(kevmoo): validate `mono_repo --help` output, too!

void main() {
  test('validate readme content', () {
    var readmeContent = File('README.md').readAsStringSync();
    expect(readmeContent, contains(_pkgConfig));
  });

  test('validate readme example output', () async {
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, _pkgConfig),
      d.file('pubspec.yaml', '''
name: sub_pkg
''')
    ]).create();

    testGenerateTravisConfig();

    await d.dir('.', [
      d.file(travisFileName, _travisYml),
      d.file(travisShPath, _travisSh)
    ]).validate();
  });
}

final _pkgConfig = r'''
# This key is required. It specifies the Dart SDKs your tests will run under
# You can provide one or more value.
# See https://docs.travis-ci.com/user/languages/dart#choosing-dart-versions-to-test-against
# for valid values
dart:
 - dev

stages:
  # Register two jobs to run under the `analyze` stage.
  - analyze:
    - dartanalyzer
    - dartfmt
  - unit_test:
    - test
''';

final _travisYml = r'''
# Created with package:mono_repo v1.2.3
language: dart

jobs:
  include:
    - stage: analyze
      name: "SDK: dev - DIR: sub_pkg - TASKS: dartanalyzer ."
      script: ./tool/travis.sh dartanalyzer
      env: PKG="sub_pkg"
      dart: dev
    - stage: analyze
      name: "SDK: dev - DIR: sub_pkg - TASKS: dartfmt -n --set-exit-if-changed ."
      script: ./tool/travis.sh dartfmt
      env: PKG="sub_pkg"
      dart: dev
    - stage: unit_test
      name: "SDK: dev - DIR: sub_pkg - TASKS: pub run test"
      script: ./tool/travis.sh test
      env: PKG="sub_pkg"
      dart: dev

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

final _travisSh = r'''
#!/bin/bash
# Created with package:mono_repo v1.2.3

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
  test) echo
    echo -e '\033[1mTASK: test\033[22m'
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
''';
