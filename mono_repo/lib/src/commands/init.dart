// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

const _pubspecFileName = 'pubspec.yaml';
const _pkgCfgFileName = 'mono_pkg.yaml';
const _repoCfgFileName = 'mono_repo.yaml';
const _recursiveScanFlag = 'recursive';

const _repoCfgContents = r'''
# See with https://github.com/dart-lang/mono_repo for details on this file
self_validate: analyze_and_format

github:
  # Setting just `cron` keeps the defaults for `push` and `pull_request`
  cron: '0 0 * * 0'
  on_completion:
    - name: "Notify failure"
      runs-on: ubuntu-latest
      # Run only if other jobs have failed and this is a push or scheduled build.
      if: (github.event_name == 'push' || github.event_name == 'schedule') && failure()
      steps:
        - run: >
            curl -H "Content-Type: application/json" -X POST -d \
              "{'text':'Build failed! ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}'}" \
              "${CHAT_WEBHOOK_URL}"
          env:
            CHAT_WEBHOOK_URL: ${{ secrets.BUILD_AND_TEST_TEAM_CHAT_WEBHOOK_URL }}

merge_stages:
- analyze_and_format
''';

const _pkgCfgContents = r'''
dart:
- dev
- stable

os:
- linux

stages:
- analyze_and_format:
  - dartanalyzer: --fatal-infos --fatal-warnings .
  - dartfmt: sdk
- unit_test:
  - test:
''';

class InitCommand extends Command<void> {
  @override
  String get name => 'init';

  @override
  String get description => 'Scaffold a new mono repo.';

  @override
  void run() => scaffold(p.current, globalResults[_recursiveScanFlag] as bool);
}

void scaffold(String rootDir, bool recursive) {
  configureDirectory(rootDir, recursive: recursive);
}

void configureDirectory(String rootDir,
    {String currentDir, bool recursive = false}) {
  currentDir ??= rootDir;

  if (currentDir == rootDir) {
    final repoCfgPath = p.join(rootDir, _repoCfgFileName);
    if (!File(repoCfgPath).existsSync()) {
      File(repoCfgPath).writeAsStringSync(_repoCfgContents);
      print(styleBold.wrap('Added $_repoCfgFileName to $rootDir'));
    } else {
      print(yellow.wrap('$_repoCfgFileName already present in $rootDir.'));
    }
  } else {
    final pkgCfgPath = p.join(currentDir, _pkgCfgFileName);
    final pubspecPath = p.join(currentDir, _pubspecFileName);

    if (File(pubspecPath).existsSync()) {
      if (!File(pkgCfgPath).existsSync()) {
        File(pkgCfgPath).writeAsStringSync(_pkgCfgContents);
        print(styleBold.wrap('Added $_pkgCfgFileName to $currentDir'));
      } else {
        print(yellow.wrap('$_pkgCfgFileName already present in $currentDir'));
      }
    }
  }

  final subdirs =
      Directory(currentDir).listSync().whereType<Directory>().toList();
  for (var subdir in subdirs) {
    if (recursive || currentDir == rootDir) {
      configureDirectory(rootDir,
          currentDir: subdir.path, recursive: recursive);
    }
  }
}
