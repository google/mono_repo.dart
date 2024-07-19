// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:mono_repo/src/root_config.dart';

// Should be ran from the `mono_repo` package directory.
void main(List<String> args) {
  final parsedArgs = argParser.parse(args);
  final validateOnly = parsedArgs['validate'] as bool;
  final versionsFile = File('lib/src/commands/github/action_versions.dart');
  if (!versionsFile.existsSync()) {
    print('Unable to find existing versions file at `${versionsFile.path}`, '
        'make sure you are running from the `mono_repo` package directory');
    exit(1);
  }
  final previousContent = versionsFile.readAsStringSync();
  final workflowFile = File('../.github/workflows/dart.yml');
  final versions =
      RootConfig.parseActionVersions(workflowFile.readAsStringSync());
  final newContentBuffer = StringBuffer('''
// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This file is generated, and should not be modified by hand.
//
// To regenerate it, run the `tool/generate_action_versions.dart` script.

''');
  for (var entry in versions.entries) {
    newContentBuffer
        .writeln("const ${entry.key.toVariableName} = '${entry.value}';");
  }
  final tmpDir = Directory.systemTemp.createTempSync('gen_action_versions');
  final tmpFile =
      File.fromUri(tmpDir.uri.resolve('generate_action_versions.dart'))
        ..writeAsStringSync(newContentBuffer.toString());
  final fmtResult =
      Process.runSync(Platform.resolvedExecutable, ['format', tmpFile.path]);
  if (fmtResult.exitCode != 0) {
    stdout
      ..writeln('Error: Failed to run dartfmt')
      ..write(fmtResult.stdout);
    stderr.write(fmtResult.stderr);
    exitCode = 1;
  } else {
    final newContent = tmpFile.readAsStringSync();

    if (previousContent == newContent) {
      print('No change');
    } else {
      stdout.write('''
Content changed!

Previous:
```
$previousContent
```

New:
```
$newContent
```
''');
      if (validateOnly) {
        exitCode = 1;
      } else {
        tmpFile.renameSync(versionsFile.path);
      }
    }
  }
  tmpDir.deleteSync(recursive: true);
}

final argParser = ArgParser()..addFlag('validate');

extension on String {
  String get toVariableName {
    final buffer = StringBuffer();
    var capitalizeNext = false;
    for (var i = 0; i < length; i++) {
      final char = this[i];
      switch (char) {
        case '-':
        case '_':
        case '/':
          capitalizeNext = true;
          continue;
        default:
          if (capitalizeNext) {
            buffer.write(char.toUpperCase());
            capitalizeNext = false;
          } else {
            buffer.write(char);
          }
      }
    }
    buffer.write('Version');
    return buffer.toString();
  }
}
