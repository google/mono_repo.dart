// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

import 'package_config.dart';
import 'travis_config.dart';

final packageConfigFileName = 'packages.yaml';

Map<String, PackageConfig> openPackageConfig({String rootDirectory}) {
  rootDirectory ??= p.current;

  var packagesFile = new File(p.join(rootDirectory, packageConfigFileName));

  // TODO: better error if file does not exist

  var yaml = y.loadYaml(packagesFile.readAsStringSync()) as Map;

  var sortedKeys = yaml.keys.toList()..sort();

  var packages = <String, PackageConfig>{};
  for (String k in sortedKeys) {
    packages[k] = new PackageConfig.fromJson(yaml[k] as Map<String, dynamic>);
  }

  return packages;
}

/// If the file exists, open it – otherwise infer it from the data on disk.
Map<String, PackageConfig> getPackageConfig({String rootDirectory}) {
  rootDirectory ??= p.current;

  var packageFileName = p.join(rootDirectory, packageConfigFileName);

  if (FileSystemEntity.isFileSync(packageFileName)) {
    return openPackageConfig();
  }

  var packages = <String, PackageConfig>{};

  for (Directory subdir in new Directory(rootDirectory)
      .listSync()
      .where((fse) => fse is Directory)) {
    File pubspecFile = subdir.listSync().firstWhere((fse) {
      return fse is File && p.basename(fse.path) == 'pubspec.yaml';
    }, orElse: () => null);

    if (pubspecFile != null) {
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

      var publishedGuess = pubspecContent.containsKey('version');

      packages[p.relative(subdir.path, from: rootDirectory)] =
          new PackageConfig(publishedGuess);
    }
  }

  return packages;
}

Map<String, TravisConfig> getTravisConfigs({String rootDirectory}) {
  rootDirectory ??= p.current;

  var packages = getPackageConfig(rootDirectory: rootDirectory);

  if (packages.isEmpty) {
    throw new UserException('No nested packages found.');
  }

  var configs = <String, TravisConfig>{};

  for (var pkg in packages.keys) {
    var travisPath = p.join(rootDirectory, pkg, travisFileName);
    var travisFile = new File(travisPath);

    if (travisFile.existsSync()) {
      var travisYaml =
          y.loadYaml(travisFile.readAsStringSync(), sourceUrl: travisPath);

      var config = new TravisConfig.parse(travisYaml as Map<String, dynamic>);

      var configuredTasks =
          config.tasks.where((dt) => dt.config != null).toList();

      if (configuredTasks.isNotEmpty) {
        throw new UserException(
            'Tasks with fancy configuration are not supported. '
            'See `${p.relative(travisPath, from: rootDirectory)}`.');
      }

      configs[pkg] = config;
    }
  }
  return configs;
}

class UserException implements Exception {
  final String message;

  UserException(this.message);

  @override
  String toString() => 'UserException: $message';
}

String encodeJson(Object input) =>
    const JsonEncoder.withIndent(' ').convert(input);
