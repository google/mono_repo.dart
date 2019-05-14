// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../root_config.dart';
import 'mono_repo_command.dart';

class PubCommand extends Command<void> {
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

const _offline = 'offline';
const _dryRun = 'dry-run';
const _precompile = 'precompile';

class _PubSubCommand extends MonoRepoCommand {
  @override
  final String name;

  _PubSubCommand(this.name) {
    argParser
      ..addFlag(_offline,
          negatable: true,
          defaultsTo: false,
          help: 'Use cached packages instead of accessing the network.')
      ..addFlag(_dryRun,
          abbr: 'n',
          defaultsTo: false,
          negatable: false,
          help: 'Precompile executables and transformed dependencies.')
      ..addFlag(_precompile,
          defaultsTo: true,
          negatable: true,
          help: "Report what dependencies would change but don't change any.");
  }

  @override
  String get description => 'Run `pub $name` against all packages.';

  @override
  Future<void> run() => pub(
        rootConfig(),
        name,
        offline: argResults[_offline] as bool,
        dryRun: argResults[_dryRun] as bool,
        preCompile: argResults[_precompile] as bool,
      );
}

Future<void> pub(
  RootConfig rootConfig,
  String pubCommand, {
  @required bool offline,
  @required bool dryRun,
  @required bool preCompile,
}) async {
  final pkgDirs = rootConfig.map((pc) => pc.relativePath).toList();

  // TODO(kevmoo): use UI-as-code features when min SDK is >= 2.3.0
  final args = [pubCommand];
  if (offline) {
    args.add('--$_offline');
  }

  if (dryRun) {
    args.add('--$_dryRun');
  }

  // Note: the default is `true`
  if (!preCompile) {
    args.add('--no-$_precompile');
  }

  print(lightBlue.wrap(
      'Running `pub ${args.join(' ')}` across ${pkgDirs.length} package(s).'));

  for (var config in rootConfig) {
    final dir = config.relativePath;
    List<String> packageArgs;
    String executable;

    if (config.hasFlutterDependency) {
      executable = 'flutter';
      packageArgs = ['packages']..addAll(args);
    } else {
      executable = pubPath;
      packageArgs = args;
    }

    print('');
    print(wrapWith(
        'Starting `$executable ${packageArgs.join(' ')}` in `$dir`...',
        [styleBold, lightBlue]));
    final workingDir = p.join(rootConfig.rootDirectory, dir);

    final proc = await Process.start(executable, packageArgs,
        mode: ProcessStartMode.inheritStdio, workingDirectory: workingDir);

    final exit = await proc.exitCode;

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
  final aboveExecutable = p.dirname(p.dirname(Platform.resolvedExecutable));
  assert(FileSystemEntity.isFileSync(p.join(aboveExecutable, 'version')));
  return aboveExecutable;
})();

final String pubPath =
    p.join(_sdkDir, 'bin', Platform.isWindows ? 'pub.bat' : 'pub');
