// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;

import 'mono_config.dart';
import 'package_config.dart';
import 'user_exception.dart';
import 'utils.dart';
import 'yaml.dart';

class RootConfig extends MapBase<String, PackageConfig> {
  final MonoConfig monoConfig;
  final Map<String, PackageConfig> _configs;

  RootConfig._(this.monoConfig, this._configs);

  factory RootConfig({String rootDirectory, bool recursive = false}) {
    rootDirectory ??= p.current;

    var pkgDirs = listPackageDirectories(
        rootDirectory: rootDirectory, recursive: recursive);

    if (pkgDirs.isEmpty) {
      throw new UserException('No packages found.',
          details: 'Each target package directory must contain '
              'a `$monoPkgFileName` file.');
    }

    var configs = <String, PackageConfig>{};

    for (var pkg in pkgDirs) {
      var pkgConfigRelativePath = p.join(pkg, monoPkgFileName);

      var pkgConfigYaml = yamlMapOrNull(rootDirectory, pkgConfigRelativePath);

      if (pkgConfigYaml == null) {
        continue;
      }

      PackageConfig config;
      try {
        config = new PackageConfig.parse(pkg, pkgConfigYaml);
      } on CheckedFromJsonException catch (e) {
        throw new UserException('Error parsing $pkg/$monoPkgFileName',
            details: prettyPrintCheckedFromJsonException(e));
      }

      var configuredJobs = config.jobs
          .expand((job) => job.tasks)
          .where((task) => task.config != null)
          .toList();

      if (configuredJobs.isNotEmpty) {
        throw new UserException(
            'Tasks with fancy configuration are not supported. '
            'See `$pkgConfigRelativePath`.');
      }
      configs[pkg] = config;
    }

    return new RootConfig._(
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
