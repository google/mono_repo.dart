// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../utils.dart';

class InitCommand extends Command<Null> {
  @override
  String get name => 'init';

  @override
  String get description =>
      '''Writes a configuration file that can be user-edited.

`mono_repo` uses the `$packageConfigFileName` file, if it exists, to determine
the packages to target in the current repository.''';

  @override
  Future<Null> run() => init(recursive: globalResults[recursiveFlag] as bool);
}

Future<Null> init({bool recursive: false}) async {
  var packagesFileName = p.join(p.current, packageConfigFileName);
  // TODO: check to see if we're in the root of a GIT repo. If not, warn.

  if (FileSystemEntity.typeSync(packagesFileName) !=
      FileSystemEntityType.notFound) {
    throw new UserException('`$packagesFileName` already exists.');
  }

  var pubspecPath = p.join(p.current, 'pubspec.yaml');
  if (FileSystemEntity.typeSync(pubspecPath) != FileSystemEntityType.notFound) {
    throw new UserException(
        'Found `pubspec.yaml` in the current directory. Not supported.');
  }

  var packages = getPackageConfig(recursive: recursive);

  var file = new File(packagesFileName);
  var writer = new StringBuffer();
  writer.writeln('# Created by mono_repo');

  packages.forEach((k, v) {
    writer.writeln('$k:');
    writer.writeln('  published: ${v.published}');
  });

  file.writeAsStringSync(writer.toString(), mode: FileMode.writeOnly);
}
