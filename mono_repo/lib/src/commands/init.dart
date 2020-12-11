// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

const pubspecFileName = 'pubspec.yaml';
const pkgCfgFileName = 'mono_pkg.yaml';
const repoCfgFileName = 'mono_repo.yaml';
const recursiveScanFlag = 'recursive';

const commentText =
    '# See with https://github.com/dart-lang/mono_repo for details on this file\n';

class InitCommand extends Command<void> {
  @override
  String get name => 'init';

  @override
  String get description => 'Scaffold a new mono repo.';

  @override
  void run() => scaffold(p.current, globalResults[recursiveScanFlag]);
}

void scaffold(String rootDir, bool recursive) {
  configureDirectory(rootDir, recursive: recursive);
}

void configureDirectory(String rootDir,
    {String currentDir, bool recursive = false}) {
  currentDir ??= rootDir;

  if (currentDir == rootDir) {
    final String repoCfgPath = p.join(rootDir, repoCfgFileName);
    if (!File(repoCfgPath).existsSync()) {
      File(repoCfgPath).writeAsStringSync(commentText);
      print('Added $repoCfgFileName to $rootDir');
    } else {
      print('$repoCfgFileName already present in $rootDir. Exiting...');
      return;
    }
  } else {
    final String pkgCfgPath = p.join(currentDir, pkgCfgFileName);
    final String pubspecPath = p.join(currentDir, pubspecFileName);

    if (!File(pubspecPath).existsSync()) {
      final String pubspecContents = 'name: ${p.basename(currentDir)}\n';
      File(pubspecPath).writeAsStringSync(pubspecContents);
      print("Added $pubspecFileName to $currentDir");
    }

    if (!File(pkgCfgPath).existsSync()) {
      File(pkgCfgPath).writeAsStringSync(commentText);
      print("Added $pkgCfgFileName to $currentDir");
    }
  }

  List<Directory> subdirs =
      Directory(currentDir).listSync().whereType<Directory>().toList();
  for (Directory subdir in subdirs) {
    if (recursive || currentDir == rootDir) {
      configureDirectory(rootDir,
          currentDir: subdir.path, recursive: recursive);
    }
  }
}
