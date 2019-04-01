// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

import 'mono_config.dart';
import 'package_config.dart';
import 'user_exception.dart';
import 'yaml.dart';

const _legacyPkgConfigFileName = '.mono_repo.yml';
const _pubspecFileName = 'pubspec.yaml';

PackageConfig _packageConfigFromDir(
    String rootDirectory, String pkgRelativePath) {
  var legacyConfigPath =
      p.join(rootDirectory, pkgRelativePath, _legacyPkgConfigFileName);
  if (FileSystemEntity.isFileSync(legacyConfigPath)) {
    throw UserException(
        'Found legacy package configuration file '
        '("$_legacyPkgConfigFileName") in `$pkgRelativePath`.',
        details: 'Rename to "$monoPkgFileName".');
  }

  var pkgConfigRelativePath = p.join(pkgRelativePath, monoPkgFileName);

  var pkgConfigYaml = yamlMapOrNull(rootDirectory, pkgConfigRelativePath);

  if (pkgConfigYaml == null) {
    return null;
  }

  var pubspecFile =
      File(p.join(rootDirectory, pkgRelativePath, _pubspecFileName));

  if (!pubspecFile.existsSync()) {
    throw UserException('A `$monoPkgFileName` file was found, but missing'
        ' an expected `$_pubspecFileName` in `$pkgRelativePath`.');
  }

  var pubspec = Pubspec.parse(pubspecFile.readAsStringSync(),
      sourceUrl: pubspecFile.path);

  PackageConfig config;
  try {
    config = PackageConfig.parse(pkgRelativePath, pubspec, pkgConfigYaml);
  } on CheckedFromJsonException catch (e) {
    var details = prettyPrintCheckedFromJsonException(e);
    if (details == null) {
      rethrow;
    }
    throw UserException('Error parsing $pkgRelativePath/$monoPkgFileName',
        details: details);
  }

  return config;
}

class RootConfig extends ListBase<PackageConfig> {
  final String rootDirectory;
  final MonoConfig monoConfig;
  final List<PackageConfig> _configs;

  RootConfig._(this.rootDirectory, this.monoConfig, this._configs);

  factory RootConfig({String rootDirectory, bool recursive = true}) {
    recursive ??= true;
    rootDirectory ??= p.current;

    var configs = <PackageConfig>[];

    void visitDirectory(Directory directory) {
      var dirs = directory.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (var subdir in dirs) {
        var relativeSubDirPath = p.relative(subdir.path, from: rootDirectory);

        var pkgConfig =
            _packageConfigFromDir(rootDirectory, relativeSubDirPath);
        if (pkgConfig != null) {
          configs.add(pkgConfig);
        }

        if (recursive) {
          visitDirectory(subdir);
        }
      }
    }

    visitDirectory(Directory(rootDirectory));

    if (configs.isEmpty) {
      throw UserException('No packages found.',
          details: 'Each target package directory must contain '
              'a `$monoPkgFileName` file.');
    }

    return RootConfig._(rootDirectory,
        MonoConfig.fromRepo(rootDirectory: rootDirectory), configs);
  }

  @override
  int get length => _configs.length;

  @override
  set length(int newLength) =>
      throw UnsupportedError('This List is read-only.');

  @override
  PackageConfig operator [](int index) => _configs[index];

  @override
  void operator []=(int index, PackageConfig pkg) =>
      throw UnsupportedError('This List is read-only.');
}
