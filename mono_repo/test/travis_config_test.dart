// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Doing a copy-paste from JSON – which uses double-quotes
// ignore_for_file: prefer_single_quotes

import 'package:mono_repo/src/travis_config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart' as y;

import 'package:mono_repo/src/utils.dart';
import 'shared.dart';

Matcher throwsArgumentErrorWith(String value) =>
    throwsA((Object e) => (e as ArgumentError).message == value);

void main() {
  group('TravisConfig', () {
    test('language key required', () {
      expect(() => new TravisConfig.parse({}),
          throwsArgumentErrorWith('"language" must be set to "dart".'));
    });

    test('sdk is required config is fine', () {
      expect(
          () => new TravisConfig.parse({'language': 'dart'}),
          throwsArgumentErrorWith(
              'At least one SDK version is required under "dart".'));
    });

    test('no tasks - end up with `test`', () {
      var config = new TravisConfig.parse({
        'language': 'dart',
        'dart': ['stable']
      });

      var oneJob = config.travisJobs.single;
      expect(oneJob.sdk, 'stable');
      expect(oneJob.task.name, 'test');
      expect(oneJob.task.args, isNull);
      expect(oneJob.task.config, isNull);
    });

    test('valid example', () {
      var travisYaml = y.loadYaml(testConfig1) as Map<String, dynamic>;

      var config = new TravisConfig.parse(travisYaml);

      expect(config.sdks, unorderedEquals(['dev', 'stable', '1.23.0']));

      var jobs = config.travisJobs.toList();

      expect(encodeJson(jobs), encodeJson(_testConfig1expectedOutput));
    });

    test('before_script', () {
      var travisYaml = y.loadYaml(testConfig2) as Map<String, dynamic>;

      var config = new TravisConfig.parse(travisYaml);

      expect(config.beforeScript, 'tool/build.sh');
    });
  });
}

List get _testConfig1expectedOutput => [
      {
        "sdk": "dev",
        "task": {
          "name": "test",
          "args": "--platform dartium",
          "config": {"install_dartium": true}
        }
      },
      {
        "sdk": "dev",
        "task": {
          "name": "test",
          "args": "--preset travis --total-shards 5 --shard-index 0",
          "config": {"install_dartium": true}
        }
      },
      {
        "sdk": "dev",
        "task": {
          "name": "test",
          "args": "--preset travis --total-shards 5 --shard-index 1"
        }
      },
      {
        "sdk": "dev",
        "task": {"name": "test"}
      },
      {
        "sdk": "dev",
        "task": {
          "name": "dartanalyzer",
          "args": "--fatal-infos --fatal-warnings ."
        }
      },
      {
        "sdk": "stable",
        "task": {
          "name": "test",
          "args": "--platform dartium",
          "config": {"install_dartium": true}
        }
      },
      {
        "sdk": "stable",
        "task": {
          "name": "test",
          "args": "--preset travis --total-shards 5 --shard-index 0",
          "config": {"install_dartium": true}
        }
      },
      {
        "sdk": "stable",
        "task": {
          "name": "test",
          "args": "--preset travis --total-shards 5 --shard-index 1"
        }
      },
      {
        "sdk": "stable",
        "task": {"name": "test"}
      },
      {
        "sdk": "stable",
        "task": {
          "name": "dartanalyzer",
          "args": "--fatal-infos --fatal-warnings ."
        }
      },
      {
        "sdk": "1.23.0",
        "task": {
          "name": "test",
          "args": "--platform dartium",
          "config": {"install_dartium": true}
        }
      },
      {
        "sdk": "1.23.0",
        "task": {
          "name": "test",
          "args": "--preset travis --total-shards 5 --shard-index 0",
          "config": {"install_dartium": true}
        }
      },
      {
        "sdk": "1.23.0",
        "task": {
          "name": "test",
          "args": "--preset travis --total-shards 5 --shard-index 1"
        }
      },
      {
        "sdk": "1.23.0",
        "task": {"name": "test"}
      },
      {
        "sdk": "1.23.0",
        "task": {
          "name": "dartanalyzer",
          "args": "--fatal-infos --fatal-warnings ."
        }
      },
      {
        "sdk": "dev",
        "task": {"name": "dartfmt"}
      }
    ];
