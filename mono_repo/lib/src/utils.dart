// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

import 'mono_config.dart';
import 'package_config.dart';

const recursiveFlag = 'recursive';
final packageConfigFileName = 'mono_repo.yaml';

Map<String, PackageConfig> _openPackageConfig(String rootDirectory) {
  rootDirectory ??= p.current;

  var packagesFile = new File(p.join(rootDirectory, packageConfigFileName));

  try {
    var yaml = y.loadYaml(packagesFile.readAsStringSync());

    if (yaml == null) {
      throw new UserException(
          'Config file "$packageConfigFileName" contains no values.');
    }

    if (yaml is! Map) {
      throw new UserException(
          'Config file "$packageConfigFileName" must contain map values.');
    }

    var sortedKeys = (yaml as Map).keys.toList()..sort();

    var packages = <String, PackageConfig>{};
    for (String k in sortedKeys) {
      packages[k] = new PackageConfig.fromJson(yaml[k] as Map);
    }

    return packages;
  } on CheckedFromJsonException catch (e) {
    throw new UserException('Error parsing "$packageConfigFileName".',
        details: prettyPrintCheckedFromJsonException(e));
  }
}

/// If the file exists, open it – otherwise infer it from the data on disk.
Map<String, PackageConfig> getPackageConfig(
    {String rootDirectory, bool recursive: false}) {
  rootDirectory ??= p.current;

  var packageFileName = p.join(rootDirectory, packageConfigFileName);

  if (FileSystemEntity.isFileSync(packageFileName)) {
    return _openPackageConfig(rootDirectory);
  }

  var packages = <String, PackageConfig>{};

  void visitDirectory(Directory directory) {
    var dirs = directory.listSync().where((fse) => fse is Directory).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (Directory subdir in dirs) {
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

      if (recursive) visitDirectory(subdir);
    }
  }

  visitDirectory(new Directory(rootDirectory));

  return packages;
}

Map<String, MonoConfig> getMonoConfigs(
    {String rootDirectory, bool recursive: false}) {
  rootDirectory ??= p.current;

  var packages =
      getPackageConfig(rootDirectory: rootDirectory, recursive: recursive);

  if (packages.isEmpty) {
    throw new UserException('No nested packages found.');
  }

  var configs = <String, MonoConfig>{};

  for (var pkg in packages.keys) {
    var travisPath = p.join(rootDirectory, pkg, monoFileName);
    var travisFile = new File(travisPath);

    if (travisFile.existsSync()) {
      var travisYaml = y.loadYaml(travisFile.readAsStringSync(),
          sourceUrl: travisPath) as y.YamlMap;

      MonoConfig config;
      try {
        config = new MonoConfig.parse(pkg, travisYaml);
      } on CheckedFromJsonException catch (e) {
        throw new UserException('Error parsing $pkg/$monoFileName',
            details: prettyPrintCheckedFromJsonException(e));
      }

      var configuredJobs = config.jobs
          .expand((job) => job.tasks)
          .where((task) => task.config != null)
          .toList();

      if (configuredJobs.isNotEmpty) {
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
  final String details;

  UserException(this.message, {this.details});

  @override
  String toString() {
    var msg = 'UserException: $message';

    if (details != null) {
      msg += '\n$details';
    }
    return msg;
  }
}

String prettyPrintCheckedFromJsonException(CheckedFromJsonException err) {
  var yamlMap = err.map as y.YamlMap;

  var yamlKey = yamlMap.nodes.keys.singleWhere(
      (k) => (k as y.YamlScalar).value == err.key,
      orElse: () => null) as y.YamlScalar;

  String message;
  if (yamlKey == null) {
    assert(err.message != null);
    message = '${yamlMap.span.message(err.message.toString())}';
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
