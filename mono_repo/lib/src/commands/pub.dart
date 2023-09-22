// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../package_config.dart';
import '../utilities.dart';
import 'dart.dart';

class PubCommand extends DartCommand {
  @override
  String get name => 'pub';

  @override
  String get description =>
      'Runs the `pub` command with the provided arguments across all packages.';

  @override
  Executable executableForPackage(PackageConfig config) =>
      config.pubspec.usesFlutter ? Executable.flutter : Executable.dart;

  @override
  List<String> get arguments => ['pub', ...super.arguments];
}
