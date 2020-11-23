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
