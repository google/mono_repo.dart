import 'package:mono_repo/src/commands/travis/travis_shell.dart';

final travisShellOutput = '''
#!/bin/bash

$windowsBoilerplate

'''
    r"""
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
  pushd "${PKG}" > /dev/null || exit $?

  PUB_EXIT_CODE=0
  pub upgrade --no-precompile || PUB_EXIT_CODE=$?

  if [[ ${PUB_EXIT_CODE} -ne 0 ]]; then
    EXIT_CODE=1
    echo -e '\033[31mpub upgrade failed\033[0m'
    popd > /dev/null
    echo
    continue
  fi

  for TASK in "$@"; do
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
      echo -e "\033[31mNot expecting TASK '${TASK}'. Error!\033[0m"
      EXIT_CODE=1
      ;;
    esac
  done

  popd > /dev/null
  echo
done

exit ${EXIT_CODE}
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
      script: tool/travis.sh dartanalyzer
    - stage: analyze
      name: "SDK: dev; PKG: sub_pkg; TASKS: [`dartanalyzer .`, `dartfmt -n --set-exit-if-changed .`]"
      dart: dev
      os: osx
      env: PKGS="sub_pkg"
      script: tool/travis.sh dartanalyzer dartfmt
    - stage: unit_test
      name: "SDK: 1.23.0; PKG: sub_pkg; TASKS: chrome tests"
      dart: "1.23.0"
      os: linux
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_0
    - stage: unit_test
      name: "SDK: 1.23.0; PKG: sub_pkg; TASKS: chrome tests"
      dart: "1.23.0"
      os: windows
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_0
    - stage: unit_test
      name: "SDK: dev; PKG: sub_pkg; TASKS: chrome tests"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_0
    - stage: unit_test
      name: "SDK: dev; PKG: sub_pkg; TASKS: chrome tests"
      dart: dev
      os: windows
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_0
    - stage: unit_test
      name: "SDK: stable; PKG: sub_pkg; TASKS: chrome tests"
      dart: stable
      os: linux
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_0
    - stage: unit_test
      name: "SDK: stable; PKG: sub_pkg; TASKS: chrome tests"
      dart: stable
      os: windows
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_0
    - stage: unit_test
      name: "SDK: 1.23.0; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: "1.23.0"
      os: linux
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_1
    - stage: unit_test
      name: "SDK: 1.23.0; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: "1.23.0"
      os: windows
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_1
    - stage: unit_test
      name: "SDK: dev; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_1
    - stage: unit_test
      name: "SDK: dev; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: dev
      os: windows
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_1
    - stage: unit_test
      name: "SDK: stable; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: stable
      os: linux
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_1
    - stage: unit_test
      name: "SDK: stable; PKG: sub_pkg; TASKS: `pub run test --preset travis`"
      dart: stable
      os: windows
      env: PKGS="sub_pkg"
      script: tool/travis.sh test_1

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
