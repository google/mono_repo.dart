// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

import 'commands/github/generate.dart';
import 'mono_config.dart';
import 'package_config.dart';
import 'user_exception.dart';
import 'yaml.dart';

const _legacyPkgConfigFileName = '.mono_repo.yml';
const _pubspecFileName = 'pubspec.yaml';

PackageConfig? _packageConfigFromDir(
  String rootDirectory,
  String pkgRelativePath,
) {
  final legacyConfigPath =
      p.join(rootDirectory, pkgRelativePath, _legacyPkgConfigFileName);
  if (FileSystemEntity.isFileSync(legacyConfigPath)) {
    throw UserException(
      'Found legacy package configuration file '
      '("$_legacyPkgConfigFileName") in `$pkgRelativePath`.',
      details: 'Rename to "$monoPkgFileName".',
    );
  }

  final pkgConfigRelativePath = p.join(pkgRelativePath, monoPkgFileName);

  final pkgConfigYaml = yamlMapOrNull(rootDirectory, pkgConfigRelativePath);

  if (pkgConfigYaml == null) {
    return null;
  }

  final pubspecFile =
      File(p.join(rootDirectory, pkgRelativePath, _pubspecFileName));

  if (!pubspecFile.existsSync()) {
    throw UserException(
      'A `$monoPkgFileName` file was found, but missing'
      ' an expected `$_pubspecFileName` in `$pkgRelativePath`.',
    );
  }

  final pubspec = Pubspec.parse(
    pubspecFile.readAsStringSync(),
    sourceUrl: Uri.parse(pubspecFile.path),
  );

  return PackageConfig.parse(pkgRelativePath, pubspec, pkgConfigYaml);
}

class RootConfig extends ListBase<PackageConfig> {
  final String rootDirectory;
  final MonoConfig monoConfig;
  final List<PackageConfig> _configs;
  final Map<String, String>? existingActionVersions;

  factory RootConfig({String? rootDirectory, bool recursive = true}) {
    rootDirectory ??= p.current;

    final configs = <PackageConfig>[];

    void visitDirectory(Directory directory) {
      final dirs = directory.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (var subdir in dirs) {
        final relativeSubDirPath = p.relative(subdir.path, from: rootDirectory);

        final pkgConfig =
            _packageConfigFromDir(rootDirectory!, relativeSubDirPath);
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
      throw UserException(
        'No packages found.',
        details: 'Each target package directory must contain '
            'a `$monoPkgFileName` file.',
      );
    }

    // If a dependabot configuration file exists, assume the action versions in
    // the generated workflow file are maintained by dependabot; parse and use
    // those versions.
    Map<String, String>? existingActionVersions;
    if (File(dependabotFileName).existsSync() &&
        File(defaultGitHubWorkflowFilePath).existsSync()) {
      // TODO(devoncarew): test this
      existingActionVersions =
          _parseExistingActionVersions(File(defaultGitHubWorkflowFilePath));
    }

    return RootConfig._(
      rootDirectory,
      MonoConfig.fromRepo(rootDirectory: rootDirectory),
      configs,
      existingActionVersions,
    );
  }

  RootConfig._(
    this.rootDirectory,
    this.monoConfig,
    this._configs,
    this.existingActionVersions,
  );

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

// "dart-lang/setup-dart@6a218f2413a3e78e9087f638a238f6b40893203d"
final RegExp _usageRegex = RegExp(r'([\w-]+)\/([\w-]+)@([\w\.]+)');

Map<String, String> _parseExistingActionVersions(File file) {
  final yaml = loadYaml(file.readAsStringSync());
  final result = <String, String>{};

  void collect(dynamic yaml) {
    if (yaml is List) {
      for (var item in yaml) {
        collect(item);
      }
    } else if (yaml is Map) {
      const usesKey = 'uses';

      if (yaml.containsKey(usesKey)) {
        // dart-lang/setup-dart@6a218f2413a3e78e9087f638a238f6b40893203d
        final usage = yaml[usesKey] as String;
        final match = _usageRegex.firstMatch(usage);
        if (match != null) {
          result['${match.group(1)}/${match.group(2)}'] = match.group(3)!;
        }
      }

      for (var item in yaml.entries) {
        collect(item.value);
      }
    }
  }

  collect(yaml);
  return result;
}
