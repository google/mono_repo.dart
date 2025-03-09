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
  FOO: BAR
permissions: read-all

jobs:
  job_001:
    name: mono_repo self validate
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@d4323d4df104b026a6aa633fdb11d772146be0bf
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:stable"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@e51d8e571e22473a2ddebf0ef8a2123f0ab2c02c
        with:
          sdk: stable
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - name: mono_repo self validate
        run: dart pub global activate mono_repo 1.2.3
      - name: mono_repo self validate
        run: dart pub global run mono_repo generate --validate
  job_002:
    name: "analyze; Dart 2.17.0; `dart analyze`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@d4323d4df104b026a6aa633fdb11d772146be0bf
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0;packages:sub_pkg;commands:analyze"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@e51d8e571e22473a2ddebf0ef8a2123f0ab2c02c
        with:
          sdk: "2.17.0"
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
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
    name: "analyze; Dart 2.17.0; `dart format --output=none --set-exit-if-changed .`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@d4323d4df104b026a6aa633fdb11d772146be0bf
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0;packages:sub_pkg;commands:format"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@e51d8e571e22473a2ddebf0ef8a2123f0ab2c02c
        with:
          sdk: "2.17.0"
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart format --output=none --set-exit-if-changed ."
        run: "dart format --output=none --set-exit-if-changed ."
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
  job_004:
    name: "analyze; Dart dev; `dart analyze`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@d4323d4df104b026a6aa633fdb11d772146be0bf
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg;commands:analyze"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@e51d8e571e22473a2ddebf0ef8a2123f0ab2c02c
        with:
          sdk: dev
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: sub_pkg; dart analyze
        run: dart analyze
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
  job_005:
    name: "analyze; Dart dev; `dart format --output=none --set-exit-if-changed .`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@d4323d4df104b026a6aa633fdb11d772146be0bf
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg;commands:format"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@e51d8e571e22473a2ddebf0ef8a2123f0ab2c02c
        with:
          sdk: dev
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: "sub_pkg; dart format --output=none --set-exit-if-changed ."
        run: "dart format --output=none --set-exit-if-changed ."
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
  job_006:
    name: Notify failure
    runs-on: ubuntu-latest
    if: failure()
    steps:
      - run: |
          curl -H "Content-Type: application/json" -X POST -d \
            "{'text':'Build failed! ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}'}" \
            "${CHAT_WEBHOOK_URL}"
        env:
          CHAT_WEBHOOK_URL: "${{ secrets.CHAT_WEBHOOK_URL }}"
    needs:
      - job_001
      - job_002
      - job_003
      - job_004
      - job_005
