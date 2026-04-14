// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:mono_repo/src/package_config.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import 'package:yaml/yaml.dart' as y;

void main() {
  group('MonoConfig', () {
    test('valid example', () {
      final pubspec = Pubspec('a');
      final pkgConfig = PackageConfig.parse(
        'a',
        pubspec,
        y.loadYaml(_testConfigYaml) as Map,
      );

      expect(pkgConfig.oses, ['linux', 'osx', 'windows']);
      expect(pkgConfig.sdks, ['1.23.0', 'dev', 'stable']);
      expect(pkgConfig.jobs, hasLength(23));

      expect(jsonDecode(jsonEncode(pkgConfig.jobs)), [
        {
          'description': 'dartanalyzer && dartfmt',
          'os': 'windows',
          'package': 'a',
          'sdk': 'dev',
          'stageName': 'analyze_and_format',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'analyze',
              'args': '--fatal-infos --fatal-warnings .',
            },
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'description': 'dartanalyzer && dartfmt',
          'os': 'linux',
          'package': 'a',
          'sdk': 'dev',
          'stageName': 'analyze_and_format',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'analyze',
              'args': '--fatal-infos --fatal-warnings .',
            },
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'osx',
          'package': 'a',
          'sdk': '1.23.0',
          'stageName': 'analyze_and_format',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'analyze',
              'args': '--fatal-infos --fatal-warnings .',
            },
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'osx',
          'package': 'a',
          'sdk': 'dev',
          'stageName': 'analyze_and_format',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'analyze',
              'args': '--fatal-infos --fatal-warnings .',
            },
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'osx',
          'package': 'a',
          'sdk': 'stable',
          'stageName': 'analyze_and_format',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'analyze',
              'args': '--fatal-infos --fatal-warnings .',
            },
          ],
          'flavor': 'dart',
          'isNewest': true,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': '1.23.0',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test', 'args': '--platform chrome'},
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': 'dev',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test', 'args': '--platform chrome'},
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': 'stable',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test', 'args': '--platform chrome'},
          ],
          'flavor': 'dart',
          'isNewest': true,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': '1.23.0',
          'stageName': 'unit_test',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'test',
              'args': '--preset travis --total-shards 5 --shard-index 0',
            },
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': 'dev',
          'stageName': 'unit_test',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'test',
              'args': '--preset travis --total-shards 5 --shard-index 0',
            },
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': 'stable',
          'stageName': 'unit_test',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'test',
              'args': '--preset travis --total-shards 5 --shard-index 0',
            },
          ],
          'flavor': 'dart',
          'isNewest': true,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': '1.23.0',
          'stageName': 'unit_test',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'test',
              'args': '--preset travis --total-shards 5 --shard-index 1',
            },
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': 'dev',
          'stageName': 'unit_test',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'test',
              'args': '--preset travis --total-shards 5 --shard-index 1',
            },
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': 'stable',
          'stageName': 'unit_test',
          'tasks': [
            {
              'flavor': 'dart',
              'type': 'test',
              'args': '--preset travis --total-shards 5 --shard-index 1',
            },
          ],
          'flavor': 'dart',
          'isNewest': true,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': '1.23.0',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test'},
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'osx',
          'package': 'a',
          'sdk': '1.23.0',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test'},
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'windows',
          'package': 'a',
          'sdk': '1.23.0',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test'},
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': 'dev',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test'},
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'osx',
          'package': 'a',
          'sdk': 'dev',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test'},
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'windows',
          'package': 'a',
          'sdk': 'dev',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test'},
          ],
          'flavor': 'dart',
          'isNewest': false,
        },
        {
          'os': 'linux',
          'package': 'a',
          'sdk': 'stable',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test'},
          ],
          'flavor': 'dart',
          'isNewest': true,
        },
        {
          'os': 'osx',
          'package': 'a',
          'sdk': 'stable',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test'},
          ],
          'flavor': 'dart',
          'isNewest': true,
        },
        {
          'os': 'windows',
          'package': 'a',
          'sdk': 'stable',
          'stageName': 'unit_test',
          'tasks': [
            {'flavor': 'dart', 'type': 'test'},
          ],
          'flavor': 'dart',
          'isNewest': true,
        },
      ]);
    });
  });
}

const _testConfigYaml = r'''
sdk: [1.23.0, dev, stable]
os: [linux, windows, osx]
stages:
- analyze_and_format:
  - description: dartanalyzer && dartfmt
    group:
    - analyze: --fatal-infos --fatal-warnings .
    - format
    os: [windows, linux]
    sdk: [dev]
  - analyze: --fatal-infos --fatal-warnings .
    os: osx
- unit_test:
  - test: --platform chrome
    os: linux
  - test: --preset travis --total-shards 5 --shard-index 0
    os: linux
  - test: --preset travis --total-shards 5 --shard-index 1
    os: linux
  - test
''';
