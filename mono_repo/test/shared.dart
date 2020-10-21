// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:checked_yaml/checked_yaml.dart';
import 'package:io/ansi.dart';
import 'package:mono_repo/src/commands/travis.dart';
import 'package:mono_repo/src/commands/travis/shared.dart'
    show skipCreatedWithSentinel;
import 'package:mono_repo/src/package_config.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:mono_repo/src/user_exception.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void testGenerateTravisConfig({
  bool validateOnly = false,
  Object printMatcher,
}) {
  printMatcher ??= isEmpty;
  final printOutput = <String>[];
  try {
    Zone.current.fork(
        zoneValues: {skipCreatedWithSentinel: true},
        specification: ZoneSpecification(print: (z1, zd, z2, value) {
          printOutput.add(value);
        })).run(
      () => overrideAnsiOutput(
        false,
        () => generateTravisConfig(
          RootConfig(rootDirectory: d.sandbox),
          validateOnly: validateOnly,
        ),
      ),
    );
  } finally {
    addTearDown(() {
      expect(printOutput.join('\n'), printMatcher);
    });
  }
}

Matcher throwsUserExceptionWith(Object message, Object details) => throwsA(
      const TypeMatcher<UserException>()
          .having((e) => e.message, 'message', message)
          .having((e) => e.details, 'details', details),
    );

Matcher throwsAParsedYamlException(Object matcher) => throwsA(
      isA<ParsedYamlException>().having(
        (e) {
          printOnFailure("r'''\n${e.formattedMessage}'''");
          return e.formattedMessage;
        },
        'formattedMessage',
        matcher,
      ),
    );

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
    - test: --preset travis
''';

String get travisShPathMessage => '''
${scriptLines(travisShPath).join('\n')}
Wrote `${p.join(d.sandbox, travisShPath)}`.''';
