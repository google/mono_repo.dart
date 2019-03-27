// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'src/runner.dart';

export 'src/runner.dart' show commands;
export 'src/user_exception.dart' show UserException;

/// Runs the executable as-if [args] was passed on the command-line.
Future<void> run(List<String> args) => MonoRepoRunner().run(args);
