// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

import 'package_config.dart';
import 'user_exception.dart';

// TODO: Use the root config file to configure top-level Travis settings
// final rootConfigFileName = 'mono_repo.yaml';
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

        var pubspecContent = y.loadYaml(pubspecFile.readAsStringSync()) as Map;
        if (pubspecContent == null) {
          throw new StateError('The pubspec file at '
              '`${pubspecFile.path}` does not appear valid.');
        }

        var name = pubspecContent['name'] as String;
        if (name == null) {
          throw new StateError(
              'No name for the pubspec at `${pubspecFile.path}`.');
        }

        packages.add(relativeSubDirPath);
      }

      if (recursive) visitDirectory(subdir);
    }
  }

  visitDirectory(new Directory(rootDirectory));

  return packages;
}

Map<String, PackageConfig> getMonoConfigs(
    {String rootDirectory, bool recursive = false}) {
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
    var pkgConfigPath = p.join(rootDirectory, pkg, monoPkgFileName);
    var pkgConfigFile = new File(pkgConfigPath);

    if (pkgConfigFile.existsSync()) {
      var pkgConfigRelativePath =
          p.relative(pkgConfigPath, from: rootDirectory);
      var pkgConfigYaml = y.loadYaml(pkgConfigFile.readAsStringSync(),
          sourceUrl: pkgConfigPath);

      if (pkgConfigYaml == null) {
        continue;
      } else if (pkgConfigYaml is y.YamlMap) {
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
      } else {
        throw UserException(
            'The contents of `$pkgConfigRelativePath` must be a Map.');
      }
    }
  }

  return configs;
}

String prettyPrintCheckedFromJsonException(CheckedFromJsonException err) {
  var yamlMap = err.map as y.YamlMap;

  y.YamlScalar _getYamlKey(String key) => yamlMap.nodes.keys
      .cast<y.YamlScalar>()
      .singleWhere((k) => k.value == key, orElse: () => null);

  var yamlKey = _getYamlKey(err.key);

  String message;
  if (yamlKey == null) {
    if (err.innerError is UnrecognizedKeysException) {
      var innerError = err.innerError as UnrecognizedKeysException;
      message = '${innerError.message}';
      for (var key in innerError.unrecognizedKeys) {
        var yamlKey = _getYamlKey(key);
        assert(yamlKey != null);
        message += '\n${yamlKey.span.message('Unrecognized key "$key"')}';
      }
    } else {
      assert(err.message != null);
      message = '${yamlMap.span.message(err.message.toString())}';
    }
  } else {
    if (err.message == null) {
      message = 'Unsupported value for `${err.key}`.';
    } else {
      message = err.message.toString();
    }
    message = yamlKey.span.message(message);
  }

  return message;
}
