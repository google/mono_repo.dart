// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'commands/check.dart';
import 'commands/dart.dart';
import 'commands/generate.dart';
import 'commands/list_command.dart';
import 'commands/mono_repo_command.dart';
import 'commands/presubmit.dart';
import 'commands/pub.dart';
import 'commands/readme_command.dart';
import 'version.dart';

final commands = List<Command<void>>.unmodifiable(
  [
    CheckCommand(),
    DartCommand(),
    GenerateCommand(),
    ListCommand(),
    PresubmitCommand(),
    PubCommand(),
    ReadmeCommand(),
  ],
);

class MonoRepoRunner extends CommandRunner<void> {
  MonoRepoRunner()
      : super(
          'mono_repo',
          'Manage multiple packages in one source repository.',
        ) {
    commands.forEach(addCommand);
    argParser
      ..addFlag(
        'version',
        negatable: false,
        help: 'Prints the version of mono_repo.',
      )
      ..addFlag(
        recursiveFlag,
        help:
            'Whether to recursively walk sub-directories looking for packages.',
        defaultsTo: true,
      )
      ..addFlag(
        'verbose',
        negatable: false,
        help: 'Show full stack trace on error. (Useful for debugging.)',
      );
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.wasParsed('version')) {
      print(packageVersion);
      return;
    }
    final verbose = topLevelResults['verbose'] as bool;
    try {
      await super.runCommand(topLevelResults);
    } catch (e, stack) {
      if (verbose) {
        print(e);
        print(stack);
      }
      rethrow;
    }
  }
}
