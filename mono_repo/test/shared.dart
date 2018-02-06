// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mono_repo/src/utils.dart';
import 'package:test/test.dart';

final isUserException = new isInstanceOf<UserException>();

Matcher throwsUserExceptionWith(String content) => throwsA(
    allOf(isUserException, (e) => (e as UserException).message == content));

final testConfig1 = r'''
dart:
  - dev
  - stable
  - 1.23.0

stages:
  - analyze_and_format:
    - dartanalyzer: --fatal-infos --fatal-warnings .
      dart:
        - dev
        - 1.23.0
    - dartfmt:
      dart:
        - dev
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
    - dartanalyzer:
      dart:
        - dev
        - 1.23.0
    - dartfmt:
      dart:
        - dev
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
