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
      - name: "Cache ~/.pub-cache/hosted"
        uses: actions/cache@v2
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;dart:stable"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
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
      - name: "Cache ~/.pub-cache/hosted"
        uses: actions/cache@v2
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg;commands:dartanalyzer"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;dart:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
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
      - name: "Cache ~/.pub-cache/hosted"
        uses: actions/cache@v2
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg;commands:dartfmt"
          restore-keys: |
            os:ubuntu-latest;pub-cache-hosted;dart:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;dart:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - env:
          PKGS: sub_pkg
          TRAVIS_OS_NAME: linux
        run: tool/ci.sh dartfmt
