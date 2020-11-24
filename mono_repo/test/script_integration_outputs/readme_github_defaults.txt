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
    name: "OS: linux; SDK: dev; PKG: sub_pkg; TASKS: `pub run test`"
    runs-on: ubuntu-latest
    steps:
      - name: Cache Pub hosted dependencies
        uses: actions/cache@v2
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg;commands:test"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;dart:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - uses: cedx/setup-dart@v2
        with:
          release-channel: dev
      - run: dart --version
      - uses: actions/checkout@v2
      - env:
          PKGS: sub_pkg
          TRAVIS_OS_NAME: linux
        run: tool/ci.sh test
  job_002:
    needs:
      - job_001
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
