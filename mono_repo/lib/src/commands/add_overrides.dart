// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../../mono_repo.dart';
import '../root_config.dart';
import 'mono_repo_command.dart';

class AddOverridesCommand extends MonoRepoCommand {
  @override
  String get name => 'add-overrides';

  @override
  String get description =>
      'Generates the CI configuration for child packages.';

  @override
  void run() => addOverrides(rootConfig());
}

void addOverrides(RootConfig config) {
  final dependencyOverrides = config.monoConfig.dependencyOverrides;
  if (dependencyOverrides.isEmpty) {
    throw UserException('No dependency_overrides defined!');
  }

  final updateQueue = <String, String>{};

  for (var package in config) {
    print(package.relativePath);
    final pubspecPath = p.join(package.relativePath, 'pubspec.yaml');
    final lockPath = p.join(package.relativePath, 'pubspec.lock');
    final lockFile = File(lockPath);

    final lockYaml =
        loadYaml(lockFile.readAsStringSync(), sourceUrl: Uri.parse(lockPath))
            as YamlMap;
    final packages = lockYaml['packages'] as YamlMap;

    final toOverride = packages.keys
        .cast<String>()
        .where((element) => dependencyOverrides.keys.contains(element))
        .toSet();

    if (toOverride.isEmpty) {
      print('Nothing to update in "$pubspecPath".');
      continue;
    }

    final pubspecFile = File(pubspecPath);
    final pubspecYaml = YamlEditor(pubspecFile.readAsStringSync());

    final pubspecOverrides = pubspecYaml
        .parseAt(['dependency_overrides'], orElse: () => wrapAsYamlNode(null));

    if (pubspecOverrides is YamlScalar && pubspecOverrides.value == null) {
      // no overrides!
      pubspecYaml.update(['dependency_overrides'], {});
    } else if (pubspecOverrides is! YamlMap) {
      throw UserException(
        '"${pubspecFile.path}" has a `dependency_overrides` value, but it is '
        'not a Map. Not sure what to do!',
      );
    }

    // We're ready to start adding dependency overrides!
    for (var newOverride in toOverride) {
      final newDep = dependencyOverrides[newOverride]!;

      Map<String, dynamic> newValue;

      if (newDep is PathDependency) {
        final path = p.isAbsolute(newDep.path)
            ? newDep.path
            : p.relative(p.absolute(newDep.path), from: package.relativePath);
        newValue = {'path': path};
      } else if (newDep is GitDependency) {
        newValue = {
          'git': <String, String>{
            'url': newDep.url.toString(),
            if (newDep.path != null) 'path': newDep.path!,
            if (newDep.ref != null) 'ref': newDep.ref!,
          }
        };
      } else {
        // TODO: support "normal" dependencies
        throw UserException('Not sure how to write `$newDep`.');
      }

      // TODO: if there is already a value at the target and it doesn't equal
      //  the value we're adding – throw!

      pubspecYaml.update(
        ['dependency_overrides', newOverride],
        newValue,
      );
    }

    updateQueue[pubspecPath] = pubspecYaml.toString();
  }

  assert(updateQueue.isNotEmpty);
  for (var entry in updateQueue.entries) {
    File(entry.key).writeAsStringSync(entry.value);
  }
}
