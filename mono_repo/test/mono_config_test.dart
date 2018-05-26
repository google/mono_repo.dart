// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Doing a copy-paste from JSON – which uses double-quotes
// ignore_for_file: prefer_single_quotes

import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:mono_repo/src/mono_config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart' as y;

import 'package:mono_repo/src/utils.dart';
import 'shared.dart';

Matcher throwsCheckedFromJsonException(String value) =>
    throwsA(allOf(const isInstanceOf<CheckedFromJsonException>(), (Object e) {
      var exp = e as CheckedFromJsonException;

      // TODO: actually validate this output as part of tests
      printOnFailure(prettyPrintCheckedFromJsonException(exp));

      printOnFailure(exp.message.toString());
      return exp.message.toString() == value;
    }));

MonoConfig _parse(Map<String, dynamic> map) => new MonoConfig.parse('a',
    y.loadYaml(const JsonEncoder.withIndent('  ').convert(map)) as y.YamlMap);

void main() {
  group('MonoConfig', () {
    test('dart key is required', () {
      expect(() => _parse({}),
          throwsCheckedFromJsonException('The "dart" key is required.'));
    });

    test('dart value cannot be null', () {
      expect(
          () => _parse({'dart': null}),
          throwsCheckedFromJsonException(
              'The "dart" key must have at least one value.'));
    });

    test('dart value cannot be empty', () {
      expect(
          () => _parse({'dart': []}),
          throwsCheckedFromJsonException(
              'The "dart" key must have at least one value.'));
    });

    test('no stages - end up with one `unit_test` stage with one `test` task',
        () {
      var config = _parse({
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
      var monoYaml = y.loadYaml(testConfig1) as y.YamlMap;

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
            () => _parse(monoYaml),
            throwsCheckedFromJsonException(
                'Stages are not allowed to have the name `test` because it '
                'interacts poorly with the default stage by the same name.'));
      });

      test('empty stage job', () {
        var monoYaml = {
          'dart': ['stable'],
          'stages': [
            {'a': []},
          ]
        };
        expect(
            () => _parse(monoYaml),
            throwsCheckedFromJsonException(
                'Stages are required to have at least one job. "a" is empty.'));
      });

      test('null stage job', () {
        var monoYaml = {
          'dart': ['stable'],
          'stages': [
            {'a': null},
          ]
        };
        expect(
            () => _parse(monoYaml),
            throwsCheckedFromJsonException(
                'Stages are required to have at least one job. "a" is null.'));
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
            () => _parse(monoYaml),
            throwsCheckedFromJsonException(
                'Stages muts be unique. "a" appears more than once.'));
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
