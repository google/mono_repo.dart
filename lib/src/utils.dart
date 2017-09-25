import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

import 'package_config.dart';

String get packagesFileName => p.join(p.current, 'packages.yaml');

Map<String, PackageConfig> openPackageConfig() {
  var packagesFile = new File(packagesFileName);

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
Map<String, PackageConfig> getPackageConfig() {
  if (FileSystemEntity.isFileSync(packagesFileName)) {
    return openPackageConfig();
  }

  var packages = <String, PackageConfig>{};

  for (Directory subdir
      in Directory.current.listSync().where((fse) => fse is Directory)) {
    File pubspecFile = subdir.listSync().firstWhere(
        (fse) => fse is File && p.basename(fse.path) == 'pubspec.yaml',
        orElse: () => null);

    if (pubspecFile != null) {
      var pubspecContent = y.loadYaml(pubspecFile.readAsStringSync()) as Map;

      var name = pubspecContent['name'] as String;
      if (name == null) {
        throw new StateError(
            'No name for the pubspec at `${pubspecFile.path}`.');
      }

      var publishedGuess = pubspecContent.containsKey('version');

      packages[p.relative(subdir.path)] = new PackageConfig(publishedGuess);
    }
  }

  return packages;
}

class UserException implements Exception {
  final String message;

  UserException(this.message);

  @override
  String toString() => 'UserException: $message';
}
