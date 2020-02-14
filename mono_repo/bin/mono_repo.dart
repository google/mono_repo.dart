// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:checked_yaml/checked_yaml.dart';
import 'package:io/ansi.dart' as ansi;
import 'package:io/io.dart';
import 'package:mono_repo/mono_repo.dart';

Future<void> main(List<String> arguments) async {
  try {
    await run(arguments);
  } on ParsedYamlException catch (e) {
    print(ansi.red.wrap(e.formattedMessage));
    exitCode = ExitCode.config.code;
  } on UserException catch (e) {
    print(ansi.red.wrap(e.message));
    if (e.details != null) {
      print(e.details);
    }
    exitCode = ExitCode.config.code;
  } on UsageException catch (e) {
    print(ansi.red.wrap(e.message));
    if (e.usage != null) {
      print('');
      print(e.usage);
    }
    exitCode = ExitCode.usage.code;
  }
}
