// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

part 'github_config.g.dart';

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class GitHubConfig {
  final Map<String, dynamic> on;

  // This is currently just to make JsonSerializable happy – need to fix!
  String get cron => throw UnimplementedError();

  GitHubConfig(Map<String, dynamic> on, String cron) : on = _parseOn(on, cron);

  factory GitHubConfig.fromJson(Map json) => _$GitHubConfigFromJson(json);

  Map<String, dynamic> generate() => {
        'name': 'Dart CI',
        if (on != null) 'on': on,
        'defaults': {
          'run': {'shell': 'bash'}
        }
      };
}

Map<String, dynamic> _parseOn(Map<String, dynamic> on, String cron) {
  if (on == null) {
    if (cron == null) {
      return _defaultOn;
    } else {
      return {
        ..._defaultOn,
        'schedule': [
          {'cron': cron}
        ]
      };
    }
  }

  if (cron != null) {
    throw ArgumentError.value(
      cron,
      'cron',
      'Cannot set `cron` if `on` has a value.',
    );
  }

  return on;
}

const _defaultOn = {
  'push': {
    'branches': [r'$default-branch']
  },
  'pull_request': null,
};
