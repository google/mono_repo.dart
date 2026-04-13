// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:mono_repo/src/commands/github/github_yaml.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('RootConfig', () {
    test('parseActionVersions', () async {
      final content = '''
# Created with package:mono_repo v1.2.3
name: "package:pkg_a"
on:
  push:
    branches:
      - main
    paths:
      - .github/workflows/pkg_a.yml
      - "pkg_a/**"
jobs:
  job_001:
    name: "analyze; linux; Dart 3.0.0; `dart analyze`"
    runs-on: ubuntu-latest
    steps:
      - name: Setup Dart SDK
        uses: dart-lang/setup-dart@65eb853c7ba17dde3be364c3d2858773e7144260
      - id: checkout
        name: Checkout repository
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
''';
      await d.dir('.github', [
        d.dir('workflows', [d.file('pkg_a.yml', content)]),
      ]).create();

      final file = File(path.join(d.sandbox, githubWorkflowFilePath('pkg_a')));
      final parsedVersions = RootConfig.parseActionVersions(
        file.readAsStringSync(),
      );

      expect(parsedVersions, isNotEmpty);

      final keys = parsedVersions.keys.toList();
      expect(keys, contains('actions/checkout'));
      expect(keys, contains('dart-lang/setup-dart'));
    });
  });
}
