# Created with package:mono_repo v1.2.3
name: "Dart CI"
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
      - run: "dart test"
        working-directory: "sub_pkg"
    strategy:
      fail-fast: false
      matrix:
        sdk:
          - "2.17.0"
          - "dev"
  job_002:
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
      - run: "dart test"
        working-directory: "sub_pkg"
    needs:
      - "job_001"
    strategy:
      fail-fast: false
      matrix:
        sdk:
          - "2.17.0"
          - "dev"
  job_003:
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
      - run: "dart test"
        working-directory: "sub_pkg"
    needs:
      - "job_001"
    strategy:
      fail-fast: false
      matrix:
        sdk:
          - "2.17.0"
          - "dev"
  job_004:
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

