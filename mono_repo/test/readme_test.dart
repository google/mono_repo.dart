// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:mono_repo/src/ci_test_script.dart';
import 'package:mono_repo/src/commands/ci_script/generate.dart';
import 'package:mono_repo/src/commands/github/generate.dart';
import 'package:mono_repo/src/commands/travis/generate.dart';
import 'package:mono_repo/src/package_config.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

// TODO(kevmoo): validate `mono_repo --help` output, too!

void main() {
  test('validate readme content', () {
    final readmeContent = File('README.md')
        .readAsStringSync()
        // For Windows tests
        .replaceAll('\r', '');
    expect(readmeContent, contains(_yamlWrap(_pkgYaml)));
    expect(readmeContent, contains(_yamlWrap(_repoYaml)));
  });

  test('validate readme example output', () async {
    await d.file('mono_repo.yaml', _repoYaml).create();
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, _pkgYaml),
      d.file('pubspec.yaml', '''
name: sub_pkg
''')
    ]).create();

    testGenerateConfig(
      forceTravis: false,
      forceGitHub: false,
      printMatcher: stringContainsInOrder(
        [
          'package:sub_pkg\n',
          'Make sure to mark `tool/ci.sh` as executable.\n',
          '  chmod +x tool/ci.sh\n',
        ],
      ),
    );

    await d.dir('.', [
      d.file(travisFileName, _travisYml),
      d.file(ciScriptPath, _travisSh),
      d.file(githubWorkflowFilePath('lint'), _githubLintContent),
      d.file(defaultGitHubWorkflowFilePath, _githubYamlContent),
    ]).validate();
  });
}

String _yamlWrap(String content) => '```yaml\n$content```';

const _repoYaml = r'''
# Adds a job that runs `mono_repo generate --validate` to check that everything
# is up to date.
# You can specify the value as just `true` or give a `stage` you'd like this
# job to run in.
self_validate: analyze

# This would enable both CI configurations, you probably only want one though.
travis:
github:
  # Setting just `cron` keeps the defaults for `push` and `pull_request`
  cron: '0 0 * * 0' # “At 00:00 (UTC) on Sunday.”

  # You can group stages into individual workflows  
  workflows:
    # The key here is the name of the file - .github/workflows/lint.yml
    lint:
      # This populates `name` in the workflow
      name: Dart Lint CI
      # These are the stages that are populated in the workflow file
      stages:
      - analyze
  # Any stages that are omitted here are put in a default workflow 
  # named `dart.yml`.
''';

const _pkgYaml = r'''
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

const _travisYml = r'''
# Created with package:mono_repo v1.2.3
language: dart

jobs:
  include:
    - stage: analyze
      name: mono_repo self validate
      os: linux
      script: "pub global activate mono_repo 1.2.3 && pub global run mono_repo generate --validate"
    - stage: analyze
      name: "SDK: dev; PKG: sub_pkg; TASKS: `dartanalyzer .`"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh dartanalyzer
    - stage: analyze
      name: "SDK: dev; PKG: sub_pkg; TASKS: `dartfmt -n --set-exit-if-changed .`"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh dartfmt
    - stage: unit_test
      name: "SDK: dev; PKG: sub_pkg; TASKS: `pub run test`"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh test

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
''';

const _githubLintContent = r'''
# Created with package:mono_repo v1.2.3
name: Dart Lint CI
on:
  push:
    branches:
      - main
      - master
  pull_request:
  schedule:
    - cron: "0 0 * * 0"
defaults:
  run:
    shell: bash
env:
  PUB_ENVIRONMENT: bot.github

jobs:
  job_001:
    name: mono_repo self validate
    runs-on: ubuntu-latest
    steps:
      - uses: cedx/setup-dart@v2
        with:
          release-channel: stable
          version: latest
      - run: dart --version
      - uses: actions/checkout@v2
      - run: pub global activate mono_repo 1.2.3
      - run: pub global run mono_repo generate --validate
  job_002:
    name: "OS: linux; SDK: dev; PKG: sub_pkg; TASKS: `dartanalyzer .`"
    runs-on: ubuntu-latest
    steps:
      - uses: cedx/setup-dart@v2
        with:
          release-channel: dev
      - run: dart --version
      - uses: actions/checkout@v2
      - env:
          PKGS: sub_pkg
          TRAVIS_OS_NAME: linux
        run: tool/ci.sh dartanalyzer
  job_003:
    name: "OS: linux; SDK: dev; PKG: sub_pkg; TASKS: `dartfmt -n --set-exit-if-changed .`"
    runs-on: ubuntu-latest
    steps:
      - uses: cedx/setup-dart@v2
        with:
          release-channel: dev
      - run: dart --version
      - uses: actions/checkout@v2
      - env:
          PKGS: sub_pkg
          TRAVIS_OS_NAME: linux
        run: tool/ci.sh dartfmt
''';

const _githubYamlContent = r'''
# Created with package:mono_repo v1.2.3
name: Dart CI
on:
  push:
    branches:
      - main
      - master
  pull_request:
  schedule:
    - cron: "0 0 * * 0"
defaults:
  run:
    shell: bash
env:
  PUB_ENVIRONMENT: bot.github

jobs:
  job_001:
    name: "OS: linux; SDK: dev; PKG: sub_pkg; TASKS: `pub run test`"
    runs-on: ubuntu-latest
    steps:
      - uses: cedx/setup-dart@v2
        with:
          release-channel: dev
      - run: dart --version
      - uses: actions/checkout@v2
      - env:
          PKGS: sub_pkg
          TRAVIS_OS_NAME: linux
        run: tool/ci.sh test
''';

final _travisSh = '''
$bashScriptHeader

'''
    r'''
if [[ -z ${PKGS} ]]; then
  echo -e '\033[31mPKGS environment variable must be set! - TERMINATING JOB\033[0m'
  exit 64
fi

if [[ "$#" == "0" ]]; then
  echo -e '\033[31mAt least one task argument must be provided! - TERMINATING JOB\033[0m'
  exit 64
fi

SUCCESS_COUNT=0
declare -a FAILURES

for PKG in ${PKGS}; do
  echo -e "\033[1mPKG: ${PKG}\033[22m"
  EXIT_CODE=0
  pushd "${PKG}" >/dev/null || EXIT_CODE=$?

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo -e "\033[31mPKG: '${PKG}' does not exist - TERMINATING JOB\033[0m"
    exit 64
  fi

  pub upgrade --no-precompile || EXIT_CODE=$?

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo -e "\033[31mPKG: ${PKG}; 'pub upgrade' - FAILED  (${EXIT_CODE})\033[0m"
    FAILURES+=("${PKG}; 'pub upgrade'")
  else
    for TASK in "$@"; do
      EXIT_CODE=0
      echo
      echo -e "\033[1mPKG: ${PKG}; TASK: ${TASK}\033[22m"
      case ${TASK} in
      dartanalyzer)
        echo 'dartanalyzer .'
        dartanalyzer . || EXIT_CODE=$?
        ;;
      dartfmt)
        echo 'dartfmt -n --set-exit-if-changed .'
        dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
        ;;
      test)
        echo 'pub run test'
        pub run test || EXIT_CODE=$?
        ;;
      *)
        echo -e "\033[31mUnknown TASK '${TASK}' - TERMINATING JOB\033[0m"
        exit 64
        ;;
      esac

      if [[ ${EXIT_CODE} -ne 0 ]]; then
        echo -e "\033[31mPKG: ${PKG}; TASK: ${TASK} - FAILED (${EXIT_CODE})\033[0m"
        FAILURES+=("${PKG}; TASK: ${TASK}")
      else
        echo -e "\033[32mPKG: ${PKG}; TASK: ${TASK} - SUCCEEDED\033[0m"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      fi

    done
  fi

  echo
  echo -e "\033[32mSUCCESS COUNT: ${SUCCESS_COUNT}\033[0m"

  if [ ${#FAILURES[@]} -ne 0 ]; then
    echo -e "\033[31mFAILURES: ${#FAILURES[@]}\033[0m"
    for i in "${FAILURES[@]}"; do
      echo -e "\033[31m  $i\033[0m"
    done
  fi

  popd >/dev/null || exit 70
  echo
done

if [ ${#FAILURES[@]} -ne 0 ]; then
  exit 1
fi
''';
