// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;

import 'user_exception.dart';
import 'yaml.dart';

part 'mono_config.g.dart';

final _monoConfigFileName = 'mono_repo.yaml';

/// The top-level keys that cannot be set under `travis:` in  `mono_repo.yaml`
const _reservedTravisKeys = ['cache', 'branches', 'stages', 'jobs', 'language'];

@JsonSerializable(createToJson: false)
class MonoConfig {
  final Map<String, dynamic> travis;

  MonoConfig(this.travis) {
    var overlappingKeys =
        travis.keys.where(_reservedTravisKeys.contains).toList();
    if (overlappingKeys.isNotEmpty) {
      throw ArgumentError.value(travis, 'travis',
          'Contains illegal keys: ${overlappingKeys.join(', ')}');
    }
  }

  factory MonoConfig.fromJson(Map json) => _$MonoConfigFromJson(json);

  factory MonoConfig.fromRepo({String rootDirectory}) {
    rootDirectory ??= p.current;

    var yaml = yamlMapOrNull(rootDirectory, _monoConfigFileName);
    if (yaml == null || yaml.isEmpty) {
      return new MonoConfig({});
    }

    try {
      return new MonoConfig.fromJson(yaml);
    } on CheckedFromJsonException catch (e) {
      throw new UserException('Error parsing $_monoConfigFileName',
          details: prettyPrintCheckedFromJsonException(e));
    }
  }
}
