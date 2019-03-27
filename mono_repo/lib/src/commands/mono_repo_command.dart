// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../root_config.dart';

const recursiveFlag = 'recursive';

abstract class MonoRepoCommand extends Command<void> {
  RootConfig rootConfig() => RootConfig(
      rootDirectory: p.current,
      recursive: globalResults[recursiveFlag] as bool);
}
