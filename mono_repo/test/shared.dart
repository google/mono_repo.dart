// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:checked_yaml/checked_yaml.dart';
import 'package:io/ansi.dart';
import 'package:mono_repo/src/commands/travis.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:mono_repo/src/user_exception.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

const createdWithText = 'Created with package:mono_repo v2.4.1-dev';

Future<void> testGenerateTravisConfig({bool validateOnly = false}) async {
  overrideAnsiOutput(false, () {
    generateTravisConfig(RootConfig(rootDirectory: d.sandbox),
        pkgVersion: '1.2.3', validateOnly: validateOnly);
  });
}

/// Creates a function similar to [testGenerateTravisConfig], except with
/// custom arguments gives to [generateTravisConfig].
///
/// If no arguments are given, the output should have the exact same behavior
/// as [generateTravisConfig].
Function testGenerateCustomTravisConfig(
        {bool prettyAnsi = true,
        bool useGet = false,
        String pkgVersion = '1.2.3'}) =>
    () => overrideAnsiOutput(false, () {
          generateTravisConfig(RootConfig(rootDirectory: d.sandbox),
              prettyAnsi: prettyAnsi, useGet: useGet, pkgVersion: pkgVersion);
        });

Matcher throwsUserExceptionWith(Object message, Object details) =>
    throwsA(const TypeMatcher<UserException>()
        .having((e) => e.message, 'message', message)
        .having((e) => e.details, 'details', details));

Matcher throwsAParsedYamlException(Object matcher) =>
    throwsA(isA<ParsedYamlException>().having((e) {
      printOnFailure("r'''\n${e.formattedMessage}'''");
      return e.formattedMessage;
    }, 'formattedMessage', matcher));

const testConfig2 = r'''
dart:
 - dev
 - stable
 - 1.23.0

os:
  - linux
  - windows

stages:
  - analyze:
    - group:
        - dartanalyzer
        - dartfmt
      dart:
        - dev
      os:
        - osx
    - dartanalyzer:
      dart:
        - 1.23.0
      os:
        - windows
  - unit_test:
    - description: "chrome tests"
      test: --platform chrome
    - test: --preset travis --total-shards 9 --shard-index 0
    - test: --preset travis --total-shards 9 --shard-index 1
    - test: --preset travis --total-shards 9 --shard-index 2
    - test: --preset travis --total-shards 9 --shard-index 3
    - test: --preset travis --total-shards 9 --shard-index 4
    - test: --preset travis --total-shards 9 --shard-index 5
    - test: --preset travis --total-shards 9 --shard-index 6
    - test: --preset travis --total-shards 9 --shard-index 7
    - test: --preset travis --total-shards 9 --shard-index 8
    - test
''';
