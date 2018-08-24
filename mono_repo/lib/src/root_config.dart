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
    throw new UserException(
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
      new File(p.join(rootDirectory, pkgRelativePath, _pubspecFileName));

  if (!pubspecFile.existsSync()) {
    throw UserException('A `$monoPkgFileName` file was found, but missing'
        ' an expected `$_pubspecFileName` in `$pkgRelativePath`.');
  }

  var pubspec = Pubspec.parse(pubspecFile.readAsStringSync(),
      sourceUrl: pubspecFile.path);

  PackageConfig config;
  try {
    config = new PackageConfig.parse(pkgRelativePath, pubspec, pkgConfigYaml);
  } on CheckedFromJsonException catch (e) {
    throw new UserException('Error parsing $pkgRelativePath/$monoPkgFileName',
        details: prettyPrintCheckedFromJsonException(e));
  }

  // TODO(kevmoo): Now that we can write yaml, we should support round-tripping
  // more complex task configurations
  var configuredJobs = config.jobs
      .expand((job) => job.tasks)
      .where((task) => task.config != null)
      .toList();

  if (configuredJobs.isNotEmpty) {
    throw new UserException('Tasks with fancy configuration are not supported. '
        'See `$pkgConfigRelativePath`.');
  }

  return config;
}

class RootConfig extends MapBase<String, PackageConfig> {
  final String rootDirectory;
  final MonoConfig monoConfig;
  final Map<String, PackageConfig> _configs;

  RootConfig._(this.rootDirectory, this.monoConfig, this._configs);

  factory RootConfig({String rootDirectory, bool recursive = false}) {
    rootDirectory ??= p.current;

    var configs = <String, PackageConfig>{};

    void visitDirectory(Directory directory) {
      var dirs = directory.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (var subdir in dirs) {
        var relativeSubDirPath = p.relative(subdir.path, from: rootDirectory);

        var pkgConfig =
            _packageConfigFromDir(rootDirectory, relativeSubDirPath);
        if (pkgConfig != null) {
          configs[relativeSubDirPath] = pkgConfig;
        }

        if (recursive) {
          visitDirectory(subdir);
        }
      }
    }

    visitDirectory(new Directory(rootDirectory));

    if (configs.isEmpty) {
      throw new UserException('No packages found.',
          details: 'Each target package directory must contain '
              'a `$monoPkgFileName` file.');
    }

    return new RootConfig._(rootDirectory,
        MonoConfig.fromRepo(rootDirectory: rootDirectory), configs);
  }

  @override
  PackageConfig operator [](Object key) => _configs[key];

  @override
  Iterable<String> get keys => _configs.keys;

  @override
  void operator []=(String key, PackageConfig value) =>
      throw UnsupportedError('This Map is read-only.');

  @override
  void clear() => throw UnsupportedError('This Map is read-only.');

  @override
  PackageConfig remove(Object key) =>
      throw UnsupportedError('This Map is read-only.');
}
