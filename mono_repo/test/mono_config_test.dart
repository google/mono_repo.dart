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

String _encodeJson(Object input) =>
    const JsonEncoder.withIndent('  ').convert(input);

Matcher throwsCheckedFromJsonException(String prettyValue) => throwsA(allOf(
    const isInstanceOf<CheckedFromJsonException>(),
    new FeatureMatcher<CheckedFromJsonException>('prettyPrint', (e) {
      var prettyValue = prettyPrintCheckedFromJsonException(e);
      printOnFailure("r'''\n$prettyValue'''");
      return prettyValue;
    }, prettyValue)));

MonoConfig _parse(map) =>
    new MonoConfig.parse('a', y.loadYaml(_encodeJson(map)) as y.YamlMap);

void _expectParseThrows(Object content, String expectedError) => expect(
    () => _parse(content), throwsCheckedFromJsonException(expectedError));

void main() {
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

    expect(_encodeJson(jobs), _encodeJson(_testConfig1expectedOutput));
  });

  group('error checks', () {
    test('dart key is required', () {
      _expectParseThrows({}, r'''
line 1, column 1: The "dart" key is required.
{}
^^''');
    });

    test('dart value cannot be null', () {
      _expectParseThrows({'dart': null}, r'''
line 2, column 3: The "dart" key must have at least one value.
  "dart": null
  ^^^^^^''');
    });

    test('dart value cannot be empty', () {
      _expectParseThrows({'dart': []}, r'''
line 2, column 3: The "dart" key must have at least one value.
  "dart": []
  ^^^^^^''');
    });

    test('Stages named `test` are not allowed', () {
      var monoYaml = {
        'dart': ['stable'],
        'stages': [
          {
            'test': ['test']
          },
        ]
      };
      _expectParseThrows(monoYaml, r'''
line 7, column 7: Stages are not allowed to have the name `test` because it interacts poorly with the default stage by the same name.
      "test": [
      ^^^^^^''');
    });

    test('Stages tasks must be a list', () {
      var monoYaml = {
        'dart': ['stable'],
        'stages': [
          {'a': 42},
        ]
      };

      _expectParseThrows(monoYaml, r'''
line 7, column 7: `stages` expects a list of maps with exactly one key (the name of the stage). The provided value `{a: 42}` is not valid.
      "a": 42
      ^^^''');
    });

    test('Stages tasks must be a list', () {
      var monoYaml = {
        'dart': ['stable'],
        'stages': [
          {'a': 42},
        ]
      };

      _expectParseThrows(monoYaml, r'''
line 7, column 7: `stages` expects a list of maps with exactly one key (the name of the stage). The provided value `{a: 42}` is not valid.
      "a": 42
      ^^^''');
    });

    test(
        'Stages tasks must be a list with map with one key in the approved set',
        () {
      var monoYaml = {
        'dart': ['stable'],
        'stages': [
          {
            'a': [
              {'weird': 'thing'}
            ]
          },
        ]
      };

      _expectParseThrows(monoYaml, r'''
line 9, column 11: Must have one key of `dartfmt`, `dartanalyzer`, `test`, `command`.
          "weird": "thing"
          ^^^^^^^''');
    });

    test('Stage tasks entries must have one key in the approved set', () {
      var monoYaml = {
        'dart': ['stable'],
        'stages': [
          {
            'a': [
              {'test': 'thing', 'command': 'other thing'}
            ]
          },
        ]
      };

      _expectParseThrows(monoYaml, r'''
line 10, column 11: Must have one and only one key of `dartfmt`, `dartanalyzer`, `test`, `command`.
          "command": "other thing"
          ^^^^^^^^^''');
    });

    test('empty stage job', () {
      var monoYaml = {
        'dart': ['stable'],
        'stages': [
          {'a': []},
        ]
      };
      _expectParseThrows(monoYaml, r'''
line 7, column 7: Stages are required to have at least one job. "a" is empty.
      "a": []
      ^^^''');
    });

    test('multiple keys under a stage', () {
      var monoYaml = {
        'dart': ['stable'],
        'stages': [
          {'a': null, 'b': null},
        ]
      };
      _expectParseThrows(monoYaml, r'''
line 8, column 7: `stages` expects a list of maps with exactly one key (the name of the stage), but the provided value has 2 values.
      "b": null
      ^^^''');
    });

    test('no keys under a stage', () {
      var monoYaml = {
        'dart': ['stable'],
        'stages': [{}]
      };
      _expectParseThrows(monoYaml, r'''
line 6, column 5: `stages` expects a list of maps with exactly one key (the name of the stage), but no items exist.
    {}
    ^^''');
    });

    test('null stage job', () {
      var monoYaml = {
        'dart': ['stable'],
        'stages': [
          {'a': null},
        ]
      };
      _expectParseThrows(monoYaml, r'''
line 7, column 7: Stages are required to have at least one job. "a" is null.
      "a": null
      ^^^''');
    });

    test('unsupported keys', () {
      var monoYaml = {
        'extra': 'foo',
        'dart': ['stable'],
        'stages': [
          {
            'a': ['test']
          },
          {
            'a': ['dartfmt']
          },
        ],
        'more': null
      };
      _expectParseThrows(monoYaml, r'''
Unrecognized keys: [extra, more]; supported keys: [dart, stages]
line 2, column 3: Unrecognized key "extra"
  "extra": "foo",
  ^^^^^^^
line 18, column 3: Unrecognized key "more"
  "more": null
  ^^^^^^''');
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

      _expectParseThrows(monoYaml, r'''
line 12, column 7: Stages muts be unique. "a" appears more than once.
      "a": [
      ^^^''');
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
