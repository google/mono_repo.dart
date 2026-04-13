const ciShellOutput = r'''
#!/bin/bash
# Created with package:mono_repo v1.2.3

# Support built in commands on windows out of the box.

# When it is a flutter repo (check the pubspec.yaml for "sdk: flutter")
# then "flutter pub" is called instead of "dart pub".
# This assumes that the Flutter SDK has been installed in a previous step.
function pub() {
  if grep -Fq "sdk: flutter" "${PWD}/pubspec.yaml"; then
    command flutter pub "$@"
  else
    command dart pub "$@"
  fi
}

function format() {
  command dart format "$@"
}

# When it is a flutter repo (check the pubspec.yaml for "sdk: flutter")
# then "flutter analyze" is called instead of "dart analyze".
# This assumes that the Flutter SDK has been installed in a previous step.
function analyze() {
  if grep -Fq "sdk: flutter" "${PWD}/pubspec.yaml"; then
    command flutter analyze "$@"
  else
    command dart analyze "$@"
  fi
}

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

  dart pub upgrade || EXIT_CODE=$?

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo -e "\033[31mPKG: ${PKG}; 'dart pub upgrade' - FAILED  (${EXIT_CODE})\033[0m"
    FAILURES+=("${PKG}; 'dart pub upgrade'")
  else
    for TASK in "$@"; do
      EXIT_CODE=0
      echo
      echo -e "\033[1mPKG: ${PKG}; TASK: ${TASK}\033[22m"
      case ${TASK} in
      analyze)
        echo 'dart analyze'
        dart analyze || EXIT_CODE=$?
        ;;
      format)
        echo 'dart format --output=none --set-exit-if-changed .'
        dart format --output=none --set-exit-if-changed . || EXIT_CODE=$?
        ;;
      test_0)
        echo 'dart test --platform chrome'
        dart test --platform chrome || EXIT_CODE=$?
        ;;
      test_1)
        echo 'dart test --preset travis'
        dart test --preset travis || EXIT_CODE=$?
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

const githubConfigOutput = r'''
# Created with package:mono_repo v1.2.3
name: "package:pkg_name"
on:
  push:
    branches:
      - main
      - master
    paths:
      - .github/workflows/sub_pkg.yml
      - "sub_pkg/**"
  pull_request:
defaults:
  run:
    shell: bash
env:
  PUB_ENVIRONMENT: bot.github
permissions: read-all

jobs:
  job_001:
    name: "analyze; osx; Dart dev; `dart analyze`, `true`"
    runs-on: macos-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7
        with:
          path: "~/.pub-cache/hosted"
          key: "os:macos-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg;commands:analyze-format"
          restore-keys: |
            os:macos-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg
            os:macos-latest;pub-cache-hosted;sdk:dev
            os:macos-latest;pub-cache-hosted
            os:macos-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: dev
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: sub_pkg; dart analyze
        run: dart analyze
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
      - name: sub_pkg; true
        run: "true"
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
  job_002:
    name: "analyze; windows; Dart 1.23.0; `dart analyze`"
    runs-on: windows-latest
    steps:
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: "1.23.0"
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: sub_pkg; dart analyze
        run: dart analyze
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
  job_003:
    name: "unit_test; linux; Dart 1.23.0; `dart test --preset travis`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:1.23.0;packages:sub_pkg;commands:test_0"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:1.23.0;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:1.23.0
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: "1.23.0"
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --preset travis"
        run: dart test --preset travis
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_004:
    name: unit_test; linux; Dart 1.23.0; chrome tests
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:1.23.0;packages:sub_pkg;commands:test_1"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:1.23.0;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:1.23.0
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: "1.23.0"
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --platform chrome"
        run: dart test --platform chrome
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_005:
    name: "unit_test; linux; Dart dev; `dart test --preset travis`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg;commands:test_0"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: dev
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --preset travis"
        run: dart test --preset travis
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_006:
    name: unit_test; linux; Dart dev; chrome tests
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg;commands:test_1"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: dev
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --platform chrome"
        run: dart test --platform chrome
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_007:
    name: "unit_test; linux; Dart stable; `dart test --preset travis`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:stable;packages:sub_pkg;commands:test_0"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:stable;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:stable
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: stable
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --preset travis"
        run: dart test --preset travis
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_008:
    name: unit_test; linux; Dart stable; chrome tests
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:stable;packages:sub_pkg;commands:test_1"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:stable;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:stable
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: stable
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --platform chrome"
        run: dart test --platform chrome
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_009:
    name: "unit_test; windows; Dart 1.23.0; `dart test --preset travis`"
    runs-on: windows-latest
    steps:
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: "1.23.0"
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --preset travis"
        run: dart test --preset travis
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_010:
    name: unit_test; windows; Dart 1.23.0; chrome tests
    runs-on: windows-latest
    steps:
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: "1.23.0"
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --platform chrome"
        run: dart test --platform chrome
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_011:
    name: "unit_test; windows; Dart dev; `dart test --preset travis`"
    runs-on: windows-latest
    steps:
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: dev
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --preset travis"
        run: dart test --preset travis
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_012:
    name: unit_test; windows; Dart dev; chrome tests
    runs-on: windows-latest
    steps:
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: dev
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --platform chrome"
        run: dart test --platform chrome
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_013:
    name: "unit_test; windows; Dart stable; `dart test --preset travis`"
    runs-on: windows-latest
    steps:
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: stable
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --preset travis"
        run: dart test --preset travis
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_014:
    name: unit_test; windows; Dart stable; chrome tests
    runs-on: windows-latest
    steps:
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
        with:
          sdk: stable
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart test --platform chrome"
        run: dart test --platform chrome
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
''';

const ciShellOutputMultiFlavor = ciShellOutput;
