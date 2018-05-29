// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:mono_repo/src/utils.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

final isUserException = const isInstanceOf<UserException>();

Matcher throwsUserExceptionWith(String message, [String details]) {
  var items = <Matcher>[
    isUserException,
    predicate((e) => (e as UserException).message == message,
        'has message: "$message".')
  ];

  if (details != null) {
    items.add(predicate((e) {
      printOnFailure((e as UserException).details);
      return (e as UserException).details == details;
    }, 'has details: "$details"'));
  }

  return throwsA(allOf(items));
}

Future sharedSetup() async {
  await d.dir('foo', [
    d.file('pubspec.yaml', r'''
name: foo

dependencies:
  build: any
  implied_any:
''')
  ]).create();

  await d.dir('bar', [
    d.file('pubspec.yaml', r'''
name: bar

dependencies:
  build:
    git:
      url: https://github.com/dart-lang/build.git
      path: build
      ref: hacking
''')
  ]).create();

  await d.dir('baz', [
    d.file('pubspec.yaml', r'''
name: baz

dependencies:
  build:
    git: https://github.com/dart-lang/build.git
dependency_overrides:
  analyzer:
'''),
    d.dir('recursive', [
      d.file('pubspec.yaml', r'''
name: baz.recursive

dependencies:
  baz: any
        '''),
    ]),
  ]).create();

  await d.dir('flutter', [
    // typical pubspec.yaml from flutter
    d.file('pubspec.yaml', r'''
name: flutter
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^0.1.0
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
  assets:
   - images/a_dot_burr.jpeg
  fonts:
    - family: Schyler
      fonts:
        - asset: fonts/Schyler-Regular.ttf
        - asset: fonts/Schyler-Italic.ttf
          style: italic
          weight: 700
''')
  ]).create();
}

final testConfig1 = r'''
dart:
  - dev
  - stable
  - 1.23.0

stages:
  - analyze_and_format:
    - group:
        - dartanalyzer: --fatal-infos --fatal-warnings .
        - dartfmt
      dart:
        - dev
    - dartanalyzer: --fatal-infos --fatal-warnings .
      dart:
        - 1.23.0
  - unit_test:
    - test: --platform chrome
      xvfb: true
    - test: --preset travis --total-shards 5 --shard-index 0
      xvfb: true
    - test: --preset travis --total-shards 5 --shard-index 1
    - test #no args
''';

final testConfig2 = r'''
dart:
 - dev
 - stable
 - 1.23.0

stages:
  - analyze:
    - group:
        - dartanalyzer
        - dartfmt
      dart:
        - dev
    - dartanalyzer:
      dart:
        - 1.23.0
  - unit_test:
    - test: --platform chrome
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
