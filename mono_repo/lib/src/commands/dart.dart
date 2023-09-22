// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../package_config.dart';
import '../root_config.dart';
import 'mono_repo_command.dart';

class DartCommand extends MonoRepoCommand {
  @override
  final ArgParser argParser = ArgParser.allowAnything();

  @override
  String get name => 'dart';

  @override
  String get description =>
      'Runs the `dart` command with the provided arguments across all '
      'packages.';

  @override
  Future<void> run() => dart(
        rootConfig(),
        arguments,
        executableForPackage,
      );

  /// The arguments to pass to the executable.
  List<String> get arguments => argResults?.rest ?? const [];

  /// The executable to use for a given package.
  Executable executableForPackage(PackageConfig config) => Executable.dart;
}

Future<void> dart(
  RootConfig rootConfig,
  List<String> args,
  Executable Function(PackageConfig) executableForPackage,
) async {
  final pkgDirs = rootConfig.map((pc) => pc.relativePath).toList();

  print(
    lightBlue.wrap(
      'Running `dart ${args.join(' ')}` across ${pkgDirs.length} '
      'package(s).',
    ),
  );

  var successCount = 0;
  final failSet = <String>{};

  for (var config in rootConfig) {
    final dir = config.relativePath;

    print('');
    print(
      wrapWith(
        '`$dir`: Starting `${args.join(' ')}`',
        [styleBold, lightBlue],
      ),
    );
    final workingDir = p.join(rootConfig.rootDirectory, dir);

    final proc = await Process.start(
      executableForPackage(config).path,
      args,
      mode: ProcessStartMode.inheritStdio,
      workingDirectory: workingDir,
    );

    final exit = await proc.exitCode;

    if (exit == 0) {
      successCount++;
      print(wrapWith('`$dir`: success!', [styleBold, green]));
    } else {
      failSet.add(dir);
      print(wrapWith('`$dir`: failed!', [styleBold, red]));
    }

    if (rootConfig.length > 1) {
      print('');
      print('Successes: $successCount');
      if (failSet.isNotEmpty) {
        print(
          'Failures:  ${failSet.length}\n'
          '${failSet.map((e) => '  $e').join('\n')}',
        );
      }
      final remaining = rootConfig.length - (successCount + failSet.length);
      if (remaining > 0) {
        print('Remaining: $remaining');
      }
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

final String _dartPath = p.join(_sdkDir, 'bin', 'dart');

/// The "flutter[.bat]" command.
final String _flutterPath = Platform.isWindows ? 'flutter.bat' : 'flutter';

enum Executable {
  dart,
  flutter,
}

extension ExecutablePath on Executable {
  String get path => switch (this) {
        Executable.dart => _dartPath,
        Executable.flutter => _flutterPath,
      };
}
