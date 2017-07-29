// Copyright (c) 2017, Kevin Moore. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:multi_repo/multi_repo.dart';

main(List<String> arguments) async {
  await _runner.run(arguments);
}

CommandRunner get _runner => new CommandRunner(
    'multi_repo', 'Manage multiple packages in one source repository.')
  ..addCommand(new InitCommand())
  ..addCommand(new CheckCommand());
