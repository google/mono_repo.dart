# Created with package:mono_repo v1.2.3
name: "package:sub_pkg"
on:
  push:
    branches:
      - "main"
      - "master"
    paths:
      - ".github/workflows/sub_pkg.yaml"
      - "sub_pkg/**"
  pull_request:
    paths:
      - ".github/workflows/sub_pkg.yaml"
      - "sub_pkg/**"
  schedule:
    branches:
      - cron: "0 0 * * 0"
    paths:
      - ".github/workflows/sub_pkg.yaml"
      - "sub_pkg/**"
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
    name: "analyze; linux; Dart 3.0.0; `dart analyze`"
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
          sdk: "3.0.0"
          working-directory: "sub_pkg"
      - name: "dart analyze"
        run: "dart analyze"
        working-directory: "sub_pkg"
  job_002:
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
      - name: "dart analyze --fatal-infos"
        run: "dart analyze --fatal-infos"
        working-directory: "sub_pkg"
  job_003:
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
      - name: "dart format --output=none --set-exit-if-changed ."
        run: "dart format --output=none --set-exit-if-changed ."
        working-directory: "sub_pkg"
  job_004:
    name: "unit_test; linux; `dart test`"
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
          sdk: "${{ matrix.sdk }}"
          working-directory: "sub_pkg"
      - name: "dart test"
        run: "dart test"
        working-directory: "sub_pkg"
    needs:
      - "job_001"
      - "job_002"
      - "job_003"
    strategy:
      fail-fast: false
      matrix:
        sdk:
          - "3.0.0"
          - "dev"
  job_005:
    name: "cron; linux; `dart test`"
    runs-on: "ubuntu-latest"
    if: "github.event_name == 'schedule'"
    steps:
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
        with:
          persist-credentials: false
      - name: "Setup dart package"
        uses: "./.github/actions/setup-dart"
        with:
          sdk: "${{ matrix.sdk }}"
          working-directory: "sub_pkg"
      - name: "dart test"
        run: "dart test"
        working-directory: "sub_pkg"
    needs:
      - "job_001"
      - "job_002"
      - "job_003"
      - "job_004"
    strategy:
      fail-fast: false
      matrix:
        sdk:
          - "3.0.0"
          - "dev"
  job_006:
    name: "cron; windows; `dart test`"
    runs-on: "windows-latest"
    if: "github.event_name == 'schedule'"
    steps:
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
        with:
          persist-credentials: false
      - name: "Setup dart package"
        uses: "./.github/actions/setup-dart"
        with:
          sdk: "${{ matrix.sdk }}"
          working-directory: "sub_pkg"
      - name: "dart test"
        run: "dart test"
        working-directory: "sub_pkg"
    needs:
      - "job_001"
      - "job_002"
      - "job_003"
      - "job_004"
    strategy:
      fail-fast: false
      matrix:
        sdk:
          - "3.0.0"
          - "dev"
  job_007:
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
      - "job_005"
      - "job_006"

