// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/command_runner.dart';

import 'commands/check.dart';
import 'commands/init.dart';
import 'commands/presubmit.dart';
import 'commands/pub.dart';
import 'commands/travis.dart';

const _name = 'mono_repo';
const _description = 'Manage multiple packages in one source repository.';

class MonoRepoRunner extends CommandRunner<Null> {
  MonoRepoRunner() : super(_name, _description) {
    [
      new CheckCommand(),
      new InitCommand(),
      new PresubmitCommand(),
      new PubCommand(),
      new TravisCommand()
    ].forEach(addCommand);
  }
}
