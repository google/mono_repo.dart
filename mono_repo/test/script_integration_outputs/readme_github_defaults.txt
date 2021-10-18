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

jobs:
  job_001:
    name: "unit_test; linux; `dart test`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@v2.1.6
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg;commands:test"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;dart:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - uses: dart-lang/setup-dart@v1.3
        with:
          sdk: dev
      - id: checkout
        uses: actions/checkout@v2.3.5
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
        run: dart pub upgrade
      - name: sub_pkg; dart test
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
        run: dart test
  job_002:
    name: "cron; linux; `dart test`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@v2.1.6
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg;commands:test"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;dart:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - uses: dart-lang/setup-dart@v1.3
        with:
          sdk: dev
      - id: checkout
        uses: actions/checkout@v2.3.5
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
        run: dart pub upgrade
      - name: sub_pkg; dart test
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
        run: dart test
    if: "github.event_name == 'schedule'"
    needs:
      - job_001
  job_003:
    name: "cron; windows; `dart test`"
    runs-on: windows-latest
    steps:
      - uses: dart-lang/setup-dart@v1.3
        with:
          sdk: dev
      - id: checkout
        uses: actions/checkout@v2.3.5
      - id: sub_pkg_pub_upgrade
        name: sub_pkg; dart pub upgrade
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
        run: dart pub upgrade
      - name: sub_pkg; dart test
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
        run: dart test
    if: "github.event_name == 'schedule'"
    needs:
      - job_001
  job_004:
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
