// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

const _pubspecFileName = 'pubspec.yaml';
const _pkgCfgFileName = 'mono_pkg.yaml';
const _repoCfgFileName = 'mono_repo.yaml';
const _recursiveScanFlag = 'recursive';

const _commentText =
    '# See with https://github.com/dart-lang/mono_repo for details on this file\n';

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
      File(repoCfgPath).writeAsStringSync(_commentText);
      print('Added $_repoCfgFileName to $rootDir');
    } else {
      print('$_repoCfgFileName already present in $rootDir. Exiting...');
      return;
    }
  } else {
    final pkgCfgPath = p.join(currentDir, _pkgCfgFileName);
    final pubspecPath = p.join(currentDir, _pubspecFileName);

    if (!File(pubspecPath).existsSync()) {
      final pubspecContents = 'name: ${p.basename(currentDir)}\n';
      File(pubspecPath).writeAsStringSync(pubspecContents);
      print('Added $_pubspecFileName to $currentDir');
    }

    if (!File(pkgCfgPath).existsSync()) {
      File(pkgCfgPath).writeAsStringSync(_commentText);
      print('Added $_pkgCfgFileName to $currentDir');
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
