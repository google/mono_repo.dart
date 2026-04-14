# Created with package:mono_repo v1.2.3
name: "package:sub_pkg"
on:
  push:
    branches:
      - "main"
      - "master"
    paths:
      - ".github/workflows/sub_pkg.yml"
      - "sub_pkg/**"
  pull_request: null
  schedule:
    - cron: "0 0 * * 0"
defaults:
  run:
    shell: "bash"
env:
  PUB_ENVIRONMENT: "bot.github"
  FOO: "BAR"
permissions: "read-all"


jobs:
  job_001:
    name: "analyze; linux; Dart 3.0.0; `dart analyze`"
    runs-on: "ubuntu-latest"
    steps:
      - name: "Cache Pub hosted dependencies"
        uses: "actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7"
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:3.0.0;packages:sub_pkg;commands:analyze_0"
          restore-keys: |-
            os:ubuntu-latest;pub-cache-hosted;sdk:3.0.0;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:3.0.0
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: "Setup Dart SDK"
        uses: "dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260"
        with:
          sdk: "3.0.0"
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
      - id: "sub_pkg_pub_upgrade"
        name: "sub_pkg; dart pub upgrade"
        run: "dart pub upgrade"
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: "sub_pkg"
      - name: "sub_pkg; dart analyze"
        run: "dart analyze"
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: "sub_pkg"
  job_002:
    name: "analyze; linux; Dart dev; `dart analyze --fatal-infos`"
    runs-on: "ubuntu-latest"
    steps:
      - name: "Cache Pub hosted dependencies"
        uses: "actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7"
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg;commands:analyze_1"
          restore-keys: |-
            os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: "Setup Dart SDK"
        uses: "dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260"
        with:
          sdk: "dev"
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
      - id: "sub_pkg_pub_upgrade"
        name: "sub_pkg; dart pub upgrade"
        run: "dart pub upgrade"
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: "sub_pkg"
      - name: "sub_pkg; dart analyze --fatal-infos"
        run: "dart analyze --fatal-infos"
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: "sub_pkg"
  job_003:
    name: "analyze; linux; Dart dev; `dart format --output=none --set-exit-if-changed .`"
    runs-on: "ubuntu-latest"
    steps:
      - name: "Cache Pub hosted dependencies"
        uses: "actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7"
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg;commands:format"
          restore-keys: |-
            os:ubuntu-latest;pub-cache-hosted;sdk:dev;packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:dev
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: "Setup Dart SDK"
        uses: "dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260"
        with:
          sdk: "dev"
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
      - id: "sub_pkg_pub_upgrade"
        name: "sub_pkg; dart pub upgrade"
        run: "dart pub upgrade"
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: "sub_pkg"
      - name: "sub_pkg; dart format --output=none --set-exit-if-changed ."
        run: "dart format --output=none --set-exit-if-changed ."
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
        working-directory: "sub_pkg"
  job_004:
    name: "unit_test; linux; `dart test`"
    runs-on: "ubuntu-latest"
    steps:
      - name: "Cache Pub hosted dependencies"
        uses: "actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7"
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:${{ matrix.sdk }};packages:sub_pkg;commands:test"
          restore-keys: |-
            os:ubuntu-latest;pub-cache-hosted;sdk:${{ matrix.sdk }};packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:${{ matrix.sdk }}
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: "Setup Dart SDK"
        uses: "dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260"
        with:
          sdk: "${{ matrix.sdk }}"
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
      - id: "sub_pkg_pub_upgrade"
        name: "sub_pkg; dart pub upgrade"
        run: "dart pub upgrade"
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: "sub_pkg"
      - name: "sub_pkg; dart test"
        run: "dart test"
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
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
      - name: "Cache Pub hosted dependencies"
        uses: "actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7"
        with:
          path: "~/.pub-cache/hosted"
          key: "os:ubuntu-latest;pub-cache-hosted;sdk:${{ matrix.sdk }};packages:sub_pkg;commands:test"
          restore-keys: |-
            os:ubuntu-latest;pub-cache-hosted;sdk:${{ matrix.sdk }};packages:sub_pkg
            os:ubuntu-latest;pub-cache-hosted;sdk:${{ matrix.sdk }}
            os:ubuntu-latest;pub-cache-hosted
            os:ubuntu-latest
      - name: "Setup Dart SDK"
        uses: "dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260"
        with:
          sdk: "${{ matrix.sdk }}"
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
      - id: "sub_pkg_pub_upgrade"
        name: "sub_pkg; dart pub upgrade"
        run: "dart pub upgrade"
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: "sub_pkg"
      - name: "sub_pkg; dart test"
        run: "dart test"
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
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
      - name: "Setup Dart SDK"
        uses: "dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260"
        with:
          sdk: "${{ matrix.sdk }}"
      - id: "checkout"
        name: "Checkout repository"
        uses: "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd"
      - id: "sub_pkg_pub_upgrade"
        name: "sub_pkg; dart pub upgrade"
        run: "dart pub upgrade"
        if: "always() && steps.checkout.conclusion == 'success'"
        working-directory: "sub_pkg"
      - name: "sub_pkg; dart test"
        run: "dart test"
        if: "always() && steps.sub_pkg_pub_upgrade.conclusion == 'success'"
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

