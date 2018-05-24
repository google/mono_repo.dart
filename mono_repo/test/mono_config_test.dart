// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Doing a copy-paste from JSON – which uses double-quotes
// ignore_for_file: prefer_single_quotes

import 'package:mono_repo/src/mono_config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart' as y;

import 'package:mono_repo/src/utils.dart';
import 'shared.dart';

Matcher throwsArgumentErrorWith(String value) =>
    throwsA(allOf(isArgumentError, (Object e) {
      var thing = e as MonoConfigFormatError;
      printOnFailure([thing.package, thing.message].toString());
      return thing.package == 'a' && thing.message == value;
    }));

void main() {
  group('MonoConfig', () {
    test('sdk version is required', () {
      expect(
          () => new MonoConfig.parse('a', {}),
          throwsArgumentErrorWith(
              'At least one SDK version is required under "dart".'));
    });

    test('no stages - end up with one `unit_test` stage with one `test` task',
        () {
      var config = new MonoConfig.parse('a', {
        'dart': ['stable']
      });

      var oneJob = config.jobs.single;
      expect(oneJob.sdk, 'stable');
      expect(oneJob.tasks.first.name, 'test');
      expect(oneJob.tasks.first.args, isNull);
      expect(oneJob.tasks.first.config, isNull);
      expect(oneJob.stageName, 'unit_test');
    });

    test('valid example', () {
      var monoYaml = y.loadYaml(testConfig1) as Map<String, dynamic>;

      var config = new MonoConfig.parse('a', monoYaml);

      expect(config.sdks, unorderedEquals(['dev', 'stable', '1.23.0']));

      var jobs = config.jobs.toList();

      expect(encodeJson(jobs), encodeJson(_testConfig1expectedOutput));
    });

    group('error checks', () {
      test('Stages named `test` are not allowed', () {
        var monoYaml = {
          'dart': ['stable'],
          'stages': [
            {
              'test': ['test']
            },
          ]
        };
        expect(
            () => new MonoConfig.parse('a', monoYaml),
            throwsArgumentErrorWith(
                'Stages are not allowed to have the name `test` because it '
                'interacts poorly with the default stage by the same name.'));
      });

      test('Stage with no actions', () {
        var monoYaml = {
          'dart': ['stable'],
          'stages': [
            {'a': []},
          ]
        };
        expect(
            () => new MonoConfig.parse('a', monoYaml),
            throwsArgumentErrorWith(
                'Stages are required to have at least one job. '
                'Got {a: []}.'));
      });

      test('Duplicate stage names are not allowed', () {
        var monoYaml = {
          'dart': ['stable'],
          'stages': [
            {
              'a': ['test']
            },
            {
              'a': ['dartfmt']
            },
          ]
        };
        expect(
            () => new MonoConfig.parse('a', monoYaml),
            throwsArgumentErrorWith(
                'There should only be one entry for each stage, '
                'saw `a` more than once.'));
      });
    });
  });
}

List get _testConfig1expectedOutput => [
      {
        "package": "a",
        "sdk": "dev",
        "stageName": "analyze_and_format",
        "tasks": [
          {"name": "dartanalyzer", "args": "--fatal-infos --fatal-warnings ."},
          {"name": "dartfmt"}
        ]
      },
      {
        "package": "a",
        "sdk": "1.23.0",
        "stageName": "analyze_and_format",
        "tasks": [
          {"name": "dartanalyzer", "args": "--fatal-infos --fatal-warnings ."}
        ]
      },
      {
        "package": "a",
        "sdk": "dev",
        "stageName": "unit_test",
        "tasks": [
          {
            "name": "test",
            "args": "--platform chrome",
            "config": {"xvfb": true}
          }
        ]
      },
      {
        "package": "a",
        "sdk": "stable",
        "stageName": "unit_test",
        "tasks": [
          {
            "name": "test",
            "args": "--platform chrome",
            "config": {"xvfb": true}
          }
        ]
      },
      {
        "package": "a",
        "sdk": "1.23.0",
        "stageName": "unit_test",
        "tasks": [
          {
            "name": "test",
            "args": "--platform chrome",
            "config": {"xvfb": true}
          }
        ]
      },
      {
        "package": "a",
        "sdk": "dev",
        "stageName": "unit_test",
        "tasks": [
          {
            "name": "test",
            "args": "--preset travis --total-shards 5 --shard-index 0",
            "config": {"xvfb": true}
          }
        ]
      },
      {
        "package": "a",
        "sdk": "stable",
        "stageName": "unit_test",
        "tasks": [
          {
            "name": "test",
            "args": "--preset travis --total-shards 5 --shard-index 0",
            "config": {"xvfb": true}
          }
        ]
      },
      {
        "package": "a",
        "sdk": "1.23.0",
        "stageName": "unit_test",
        "tasks": [
          {
            "name": "test",
            "args": "--preset travis --total-shards 5 --shard-index 0",
            "config": {"xvfb": true}
          }
        ]
      },
      {
        "package": "a",
        "sdk": "dev",
        "stageName": "unit_test",
        "tasks": [
          {
            "name": "test",
            "args": "--preset travis --total-shards 5 --shard-index 1"
          }
        ]
      },
      {
        "package": "a",
        "sdk": "stable",
        "stageName": "unit_test",
        "tasks": [
          {
            "name": "test",
            "args": "--preset travis --total-shards 5 --shard-index 1"
          }
        ]
      },
      {
        "package": "a",
        "sdk": "1.23.0",
        "stageName": "unit_test",
        "tasks": [
          {
            "name": "test",
            "args": "--preset travis --total-shards 5 --shard-index 1"
          }
        ]
      },
      {
        "package": "a",
        "sdk": "dev",
        "stageName": "unit_test",
        "tasks": [
          {"name": "test"}
        ]
      },
      {
        "package": "a",
        "sdk": "stable",
        "stageName": "unit_test",
        "tasks": [
          {"name": "test"}
        ]
      },
      {
        "package": "a",
        "sdk": "1.23.0",
        "stageName": "unit_test",
        "tasks": [
          {"name": "test"}
        ]
      }
    ];
