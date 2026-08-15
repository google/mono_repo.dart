# Created with package:mono_repo v1.2.3
name: "Dart Lint CI"
on:
  push:
    branches:
      - "main"
      - "master"
  pull_request: null
  schedule:
    - cron: "0 0 * * 0"
defaults:
  run:
    shell: "bash"
env:
  PUB_ENVIRONMENT: "bot.github"
  FOO: "BAR"
permissions:
  contents: "read"


jobs:
  job_001:
    name: "mono_repo self validate"
    runs-on: "ubuntu-latest"
    steps:
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
        with:
          persist-credentials: false
      - name: "Setup dart package"
        uses: "./.github/actions/setup-dart"
        with:
          sdk: "stable"
      - name: "mono_repo self validate"
        run: "dart pub global activate mono_repo 1.2.3"
      - name: "mono_repo self validate"
        run: "dart pub global run mono_repo generate --validate"
  job_002:
    name: "analyze; linux; Dart 2.17.0; `dart analyze`"
    runs-on: "ubuntu-latest"
    steps:
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
        with:
          persist-credentials: false
      - name: "Setup dart package"
        uses: "./.github/actions/setup-dart"
        with:
          sdk: "2.17.0"
          working-directory: "sub_pkg"
      - run: "dart analyze"
        working-directory: "sub_pkg"
  job_003:
    name: "analyze; linux; Dart dev; `dart analyze --fatal-infos`"
    runs-on: "ubuntu-latest"
    steps:
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
        with:
          persist-credentials: false
      - name: "Setup dart package"
        uses: "./.github/actions/setup-dart"
        with:
          sdk: "dev"
          working-directory: "sub_pkg"
      - run: "dart analyze --fatal-infos"
        working-directory: "sub_pkg"
  job_004:
    name: "analyze; linux; Dart dev; `dart format --output=none --set-exit-if-changed .`"
    runs-on: "ubuntu-latest"
    steps:
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
        with:
          persist-credentials: false
      - name: "Setup dart package"
        uses: "./.github/actions/setup-dart"
        with:
          sdk: "dev"
          working-directory: "sub_pkg"
      - run: "dart format --output=none --set-exit-if-changed ."
        working-directory: "sub_pkg"
  job_005:
    name: "Notify failure"
    runs-on: "ubuntu-latest"
    if: "failure()"
    steps:
      - run: |
          curl -H "Content-Type: application/json" -X POST -d \
            "{'text':'Build failed! ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}'}" \
            "${CHAT_WEBHOOK_URL}"
        env:
          CHAT_WEBHOOK_URL: "${{ secrets.CHAT_WEBHOOK_URL }}"
    needs:
      - "job_001"
      - "job_002"
      - "job_003"
      - "job_004"

