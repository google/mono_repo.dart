# Created with package:mono_repo v1.2.3
language: dart

# Custom configuration
after_failure:
  - tool/report_failure.sh

jobs:
  include:
    - stage: analyze
      name: mono_repo self validate
      os: linux
      script: "pub global activate mono_repo 1.2.3 && pub global run mono_repo generate --validate"
    - stage: analyze
      name: "`dartanalyzer .`"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh dartanalyzer
    - stage: analyze
      name: "`dartfmt -n --set-exit-if-changed .`"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh dartfmt
    - stage: unit_test
      name: "`pub run test`"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh test
    - stage: cron
      name: "`pub run test`"
      dart: dev
      os: linux
      env: PKGS="sub_pkg"
      script: tool/ci.sh test
    - stage: cron
      name: "`pub run test`"
      dart: dev
      os: windows
      env: PKGS="sub_pkg"
      script: tool/ci.sh test

stages:
  - analyze
  - unit_test
  - cron

# Only building master means that we don't run two builds for each pull request.
branches:
  only:
    - master

cache:
  directories:
    - $HOME/.pub-cache
