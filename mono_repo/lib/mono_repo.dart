// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/command_runner.dart';

import 'src/check_command.dart';
import 'src/init_command.dart';
import 'src/presubmit_command.dart';
import 'src/pub_command.dart';
import 'src/travis_command.dart';

export 'src/utils.dart' show UserException;

final List<Command> commands = new List<Command>.unmodifiable([
  new CheckCommand(),
  new InitCommand(),
  new PresubmitCommand(),
  new PubCommand(),
  new TravisCommand()
]);
