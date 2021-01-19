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

jobs:
  job_001:
    name: mono_repo self validate
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@v2
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;dart:stable"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - uses: dart-lang/setup-dart@v0.3
        with:
          sdk: stable
      - id: checkout
        uses: actions/checkout@v2
      - name: mono_repo self validate
        run: pub global activate mono_repo 1.2.3
      - name: mono_repo self validate
        run: pub global run mono_repo generate --validate
  job_002:
    name: "analyze; `dartanalyzer .`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@v2
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg;commands:dartanalyzer"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;dart:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - uses: dart-lang/setup-dart@v0.3
        with:
          sdk: dev
      - id: checkout
        uses: actions/checkout@v2
      - id: sub_pkg_pub_upgrade
        name: "sub_pkg; pub upgrade --no-precompile"
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
        run: pub upgrade --no-precompile
      - name: sub_pkg; dartanalyzer .
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
        run: dartanalyzer .
  job_003:
    name: "analyze; `dartfmt -n --set-exit-if-changed .`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@v2
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg;commands:dartfmt"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;dart:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - uses: dart-lang/setup-dart@v0.3
        with:
          sdk: dev
      - id: checkout
        uses: actions/checkout@v2
      - id: sub_pkg_pub_upgrade
        name: "sub_pkg; pub upgrade --no-precompile"
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: sub_pkg
        run: pub upgrade --no-precompile
      - name: "sub_pkg; dartfmt -n --set-exit-if-changed ."
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: sub_pkg
        run: dartfmt -n --set-exit-if-changed .
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
