// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/ansi.dart';

import 'package:path/path.dart' as p;

import '../root_config.dart';
import 'mono_repo_command.dart';

class PubCommand extends Command<Null> {
  PubCommand() {
    addSubcommand(_PubSubCommand('get'));
    addSubcommand(_PubSubCommand('upgrade'));
  }

  @override
  String get name => 'pub';

  @override
  String get description =>
      'Run `pub get` or `pub upgrade` against all packages.';
}

class _PubSubCommand extends MonoRepoCommand {
  @override
  final String name;

  _PubSubCommand(this.name);

  @override
  String get description => 'Run `pub $name` against all packages.';

  @override
  Future<Null> run() => pub(name, rootConfig());
}

Future<Null> pub(String pubCommand, RootConfig rootConfig) async {
  print(lightBlue
      // `pub` isn't really a fitting name anymore. What do we use?
      .wrap(
          'Running `pub $pubCommand` across ${rootConfig.length} package(s).'));

  for (var config in rootConfig) {
    final dir = config.relativePath;

    List<String> arguments;
    String executable;
    if (config.hasFlutterDependency) {
      executable = Platform.isWindows ? 'flutter.bat' : 'flutter';
      arguments = ['packages', pubCommand];
    } else {
      executable = pubPath;
      arguments = [pubCommand];
    }

    print('');
    print(wrapWith('Starting `$dir`...', [styleBold, lightBlue]));
    var workingDir = p.join(rootConfig.rootDirectory, dir);

    var proc = await Process.start(executable, arguments,
        mode: ProcessStartMode.inheritStdio, workingDirectory: workingDir);

    var exit = await proc.exitCode;

    if (exit == 0) {
      print(wrapWith('`$dir`: success!', [styleBold, green]));
    } else {
      print(wrapWith('`$dir`: failed!', [styleBold, red]));
    }
  }
}

/// The path to the root directory of the SDK.
final String _sdkDir = (() {
  // The Dart executable is in "/path/to/sdk/bin/dart", so two levels up is
  // "/path/to/sdk".
  var aboveExecutable = p.dirname(p.dirname(Platform.resolvedExecutable));
  assert(FileSystemEntity.isFileSync(p.join(aboveExecutable, 'version')));
  return aboveExecutable;
})();

final String pubPath =
    p.join(_sdkDir, 'bin', Platform.isWindows ? 'pub.bat' : 'pub');