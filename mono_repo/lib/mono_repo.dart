// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:args/command_runner.dart';

import 'src/commands/check.dart';
import 'src/commands/init.dart';
import 'src/commands/presubmit.dart';
import 'src/commands/pub.dart';
import 'src/commands/travis.dart';
import 'src/runner.dart';

export 'src/utils.dart' show UserException;

final List<Command> commands = new List<Command>.unmodifiable([
  new CheckCommand(),
  new InitCommand(),
  new PresubmitCommand(),
  new PubCommand(),
  new TravisCommand()
]);

/// Runs the executable as-if [args] was passed on the command-line.
Future<Null> run(List<String> args) => new MonoRepoRunner().run(args);
