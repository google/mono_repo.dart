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
  FOO: BAR
permissions: read-all

jobs:
  job_001:
    name: "unit_test; linux; Dart 2.17.0; `dart test`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@69d9d449aced6a2ede0bc19182fadc3a0a42d2b0
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0;packages:sub_pkg;commands:test"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@a57a6c04cf7d4840e88432aad6281d1e125f0d46
        with:
          sdk: "2.17.0"
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@ac593985615ec2ede58e132d2e21d2b1cbd6127c
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: sub_pkg; dart test
        run: dart test
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
  job_002:
    name: "unit_test; linux; Dart dev; `dart test`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@69d9d449aced6a2ede0bc19182fadc3a0a42d2b0
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg;commands:test"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@a57a6c04cf7d4840e88432aad6281d1e125f0d46
        with:
          sdk: dev
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@ac593985615ec2ede58e132d2e21d2b1cbd6127c
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: sub_pkg; dart test
        run: dart test
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
  job_003:
    name: "cron; linux; Dart 2.17.0; `dart test`"
    runs-on: ubuntu-latest
    if: "github.event_name == 'schedule'"
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@69d9d449aced6a2ede0bc19182fadc3a0a42d2b0
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0;packages:sub_pkg;commands:test"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:2.17.0
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@a57a6c04cf7d4840e88432aad6281d1e125f0d46
        with:
          sdk: "2.17.0"
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@ac593985615ec2ede58e132d2e21d2b1cbd6127c
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: sub_pkg; dart test
        run: dart test
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_004:
    name: "cron; linux; Dart dev; `dart test`"
    runs-on: ubuntu-latest
    if: "github.event_name == 'schedule'"
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@69d9d449aced6a2ede0bc19182fadc3a0a42d2b0
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg;commands:test"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@a57a6c04cf7d4840e88432aad6281d1e125f0d46
        with:
          sdk: dev
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@ac593985615ec2ede58e132d2e21d2b1cbd6127c
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: sub_pkg; dart test
        run: dart test
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_005:
    name: "cron; windows; Dart 2.17.0; `dart test`"
    runs-on: windows-latest
    if: "github.event_name == 'schedule'"
    steps:
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@a57a6c04cf7d4840e88432aad6281d1e125f0d46
        with:
          sdk: "2.17.0"
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@ac593985615ec2ede58e132d2e21d2b1cbd6127c
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: sub_pkg; dart test
        run: dart test
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_006:
    name: "cron; windows; Dart dev; `dart test`"
    runs-on: windows-latest
    if: "github.event_name == 'schedule'"
    steps:
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@a57a6c04cf7d4840e88432aad6281d1e125f0d46
        with:
          sdk: dev
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@ac593985615ec2ede58e132d2e21d2b1cbd6127c
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        run: dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
      - name: sub_pkg; dart test
        run: dart test
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
    needs:
      - job_001
      - job_002
  job_007:
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
      - job_006
