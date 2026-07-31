// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:mono_repo/src/coverage_processor.dart';
import 'package:mono_repo/src/mono_config.dart';
import 'package:mono_repo/src/package_config.dart';
import 'package:mono_repo/src/utilities.dart';
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
      expect(pkgConfig.sdks, ['1.23.0', 'stable', 'dev']);
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
            {'flavor': 'dart', 'type': 'format'},
          ],
          'flavor': 'dart',
          'isNewest': true,
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
            {'flavor': 'dart', 'type': 'format'},
          ],
          'flavor': 'dart',
          'isNewest': true,
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
          'sdk': 'stable',
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
          'sdk': 'stable',
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
          'sdk': 'stable',
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
          'sdk': 'stable',
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
          'isNewest': true,
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
          'isNewest': true,
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
          'isNewest': true,
        },
      ]);
    });
  });

  group('MonoConfig.fromJson', () {
    test('default values', () {
      final config = MonoConfig.fromJson({});
      expect(config.prettyAnsi, isTrue);
      expect(config.pubAction, 'upgrade');
      expect(config.selfValidateStage, isNull);
      expect(config.defaults, isEmpty);
      expect(config.ignore, isEmpty);
      expect(config.coverageProcessors, isEmpty);
    });

    group('self_validate', () {
      test('set to true', () {
        final config = MonoConfig.fromJson({'self_validate': true});
        expect(config.selfValidateStage, 'mono_repo_self_validate');
      });

      test('set to false', () {
        final config = MonoConfig.fromJson({'self_validate': false});
        expect(config.selfValidateStage, isNull);
      });

      test('set to stage name', () {
        final config = MonoConfig.fromJson({'self_validate': 'custom_stage'});
        expect(config.selfValidateStage, 'custom_stage');
      });

      test('invalid type throws', () {
        expect(
          () => MonoConfig.fromJson({'self_validate': 123}),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
    });

    group('pretty_ansi', () {
      test('set to false', () {
        final config = MonoConfig.fromJson({'pretty_ansi': false});
        expect(config.prettyAnsi, isFalse);
      });

      test('invalid type throws', () {
        expect(
          () => MonoConfig.fromJson({'pretty_ansi': 'not_bool'}),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
    });

    group('pub_action', () {
      test('valid actions', () {
        expect(MonoConfig.fromJson({'pub_action': 'get'}).pubAction, 'get');
        expect(
          MonoConfig.fromJson({'pub_action': 'upgrade'}).pubAction,
          'upgrade',
        );
      });

      test('invalid action throws', () {
        expect(
          () => MonoConfig.fromJson({'pub_action': 'invalid'}),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
    });

    group('coverage_service', () {
      test('valid coverage processors', () {
        final config = MonoConfig.fromJson({
          'coverage_service': ['coveralls', 'codecov'],
        });
        expect(
          config.coverageProcessors,
          containsAll([CoverageProcessor.coveralls, CoverageProcessor.codecov]),
        );
      });
    });

    group('defaults and ignore', () {
      test('valid map defaults and string list ignore', () {
        final config = MonoConfig.fromJson({
          'defaults': {
            'sdk': ['dev'],
          },
          'ignore': ['sub_pkg_a'],
        });
        expect(config.defaults, {
          'sdk': ['dev'],
        });
        expect(config.ignore, contains('sub_pkg_a'));
      });

      test('invalid defaults type throws', () {
        expect(
          () => MonoConfig.fromJson({'defaults': 'not_map'}),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
    });

    test('unsupported key throws', () {
      expect(
        () => MonoConfig.fromJson({'unsupported_key': true}),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('SDK channel sorting ranks stable < beta < dev < main', () {
      final sdks = ['dev', 'stable', '3.8.0', 'main', 'pubspec', 'beta']
        ..sort(compareSdks);
      expect(sdks, ['pubspec', '3.8.0', 'stable', 'beta', 'dev', 'main']);
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
