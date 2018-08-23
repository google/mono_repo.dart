// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'package_config.dart';
import 'user_exception.dart';

const _legacyPkgConfigFileName = '.mono_repo.yml';

const pubspecFileName = 'pubspec.yaml';

/// If the file exists, open it – otherwise infer it from the data on disk.
List<String> listPackageDirectories(
    {String rootDirectory, bool recursive = false}) {
  rootDirectory ??= p.current;

  var packages = <String>[];

  void visitDirectory(Directory directory) {
    var dirs = directory.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (var subdir in dirs) {
      var relativeSubDirPath = p.relative(subdir.path, from: rootDirectory);

      var legacyConfigPath = p.join(subdir.path, _legacyPkgConfigFileName);
      if (FileSystemEntity.isFileSync(legacyConfigPath)) {
        throw new UserException(
            'Found legacy package configuration file '
            '("$_legacyPkgConfigFileName") in `$relativeSubDirPath`.',
            details: 'Rename to "$monoPkgFileName".');
      }

      var pkgConfigFilePath = p.join(subdir.path, monoPkgFileName);
      if (FileSystemEntity.isFileSync(pkgConfigFilePath)) {
        var pubspecFile = new File(p.join(subdir.path, pubspecFileName));

        if (!pubspecFile.existsSync()) {
          throw UserException('A `$monoPkgFileName` file was found, but missing'
              ' an expected `$pubspecFileName` in `$relativeSubDirPath`.');
        }

        packages.add(relativeSubDirPath);
      }

      if (recursive) visitDirectory(subdir);
    }
  }

  visitDirectory(new Directory(rootDirectory));

  return packages;
}
