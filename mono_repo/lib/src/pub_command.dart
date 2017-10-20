// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/ansi.dart';
import 'package:io/io.dart';

import 'package:path/path.dart' as p;

import 'utils.dart';

class PubCommand extends Command {
  PubCommand() {
    addSubcommand(new _PubSubCommand('get'));
    addSubcommand(new _PubSubCommand('upgrade'));
  }

  @override
  String get name => 'pub';

  @override
  String get description =>
      'Run `pub get` or `pub upgrade` against all packages.';
}

class _PubSubCommand extends Command {
  @override
  final String name;

  _PubSubCommand(this.name);

  @override
  String get description => 'Run `pub $name` against all packages.';

  @override
  Future run() => pub(name);
}

Future pub(String pubCommand, {String rootDirectory}) async {
  rootDirectory ??= p.current;
  var configs = getPackageConfig(rootDirectory: rootDirectory);

  if (configs.isEmpty) {
    return;
  }

  print(lightBlue
      .wrap('Running `pub $pubCommand` across ${configs.length} package(s).'));

  var processManager = new ProcessManager();

  for (var dir in configs.keys) {
    print('');
    print(wrapWith('Starting `$dir`...', [styleBold, lightBlue]));
    var workingDir = p.join(rootDirectory, dir);

    // TODO(kevmoo): https://github.com/dart-lang/io/issues/22
    Directory.current = workingDir;

    var proc = await processManager.spawn('pub', [pubCommand]);

    var exit = await proc.exitCode;

    if (exit == 0) {
      print(wrapWith('`$dir`: success!', [styleBold, green]));
    } else {
      print(wrapWith('`$dir`: failed!', [styleBold, red]));
    }
  }

  await ProcessManager.terminateStdIn();
}
