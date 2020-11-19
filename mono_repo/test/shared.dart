// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:checked_yaml/checked_yaml.dart';
import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:mono_repo/src/ci_shared.dart';
import 'package:mono_repo/src/commands/ci_script/generate.dart';
import 'package:mono_repo/src/commands/generate.dart';
import 'package:mono_repo/src/package_config.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:mono_repo/src/user_exception.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

Future<void> populateConfig(String monoRepoContent) async {
  await d.file('mono_repo.yaml', monoRepoContent).create();
  await d.dir('sub_pkg', [
    d.file(monoPkgFileName, testConfig2),
    d.file('pubspec.yaml', '''
name: pkg_name
      ''')
  ]).create();
}

void testGenerateTravisConfig({
  bool validateOnly = false,
  Object printMatcher,
}) =>
    testGenerateConfig(
      forceTravis: true,
      forceGitHub: false,
      validateOnly: validateOnly,
      printMatcher: printMatcher,
    );

void testGenerateBothConfig({
  bool validateOnly = false,
  Object printMatcher,
}) =>
    testGenerateConfig(
      forceGitHub: true,
      forceTravis: true,
      validateOnly: validateOnly,
      printMatcher: printMatcher,
    );

void testGenerateConfig({
  @required bool forceTravis,
  @required bool forceGitHub,
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
        () {
          final config = RootConfig(rootDirectory: d.sandbox);
          generate(
            config,
            validateOnly,
            forceTravis: forceTravis,
            forceGitHub: forceGitHub,
          );
        },
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

String get ciScriptPathMessage => '''
${scriptLines(ciScriptPath).join('\n')}
Wrote `${p.join(d.sandbox, ciScriptPath)}`.''';
