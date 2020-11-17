import 'package:mono_repo/src/ci_test_script.dart';

final ciShellOutput = '''
#!/bin/bash

$windowsBoilerplate

'''
    r"""
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
      test_0)
        echo 'pub run test --platform chrome'
        pub run test --platform chrome || EXIT_CODE=$?
        ;;
      test_1)
        echo 'pub run test --preset travis'
        pub run test --preset travis || EXIT_CODE=$?
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
""";

const travisYamlOutput = r'''
language: dart

jobs:
  include:
    - stage: analyze
      name: "SDK: 1.23.0; PKG: sub_pkg; TASKS: `dartanalyzer .`"
      dart: "1.23.0"
      os: windows
      env: PKGS="sub_pkg"
      script: tool/ci.sh dartanalyzer
    - stage: analyze
      name: "SDK: dev; PKG: sub_pkg; TASKS: [`dartanalyzer .`, `dartfmt -n --set-exit-if-changed .`]"
      dart: dev
      os: osx
      env: PKGS="sub_pkg"
      script: tool/ci.sh dartanalyzer dartfmt
    - stage: unit_test
      name: "SDK: 1.23.0; PKG: sub_pkg; TASKS: chrome tests"
      dart: "1.23.0"
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_0
    - stage: unit_test
      name: "SDK: 1.23.0; PKG: sub_pkg; TASKS: chrome tests"
      dart: "1.23.0"
      os: windows
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_0
    - stage: unit_test
      name: "SDK: dev; PKG: sub_pkg; TASKS: chrome tests"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_0
    - stage: unit_test
      name: "SDK: dev; PKG: sub_pkg; TASKS: chrome tests"
      dart: dev
      os: windows
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_0
    - stage: unit_test
      name: "SDK: stable; PKG: sub_pkg; TASKS: chrome tests"
      dart: stable
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_0
    - stage: unit_test
      name: "SDK: stable; PKG: sub_pkg; TASKS: chrome tests"
      dart: stable
      os: windows
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_0
    - stage: unit_test
      name: "SDK: 1.23.0; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: "1.23.0"
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_1
    - stage: unit_test
      name: "SDK: 1.23.0; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: "1.23.0"
      os: windows
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_1
    - stage: unit_test
      name: "SDK: dev; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_1
    - stage: unit_test
      name: "SDK: dev; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: dev
      os: windows
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_1
    - stage: unit_test
      name: "SDK: stable; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: stable
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh test_1
    - stage: unit_test
      name: "SDK: stable; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: stable
      os: windows
      env: PKGS="sub_pkg"
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
''';
