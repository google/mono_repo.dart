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
const _reservedTravisKeys = ['cache', 'jobs', 'language'];

class MonoConfig {
  final Map<String, dynamic> travis;
  final Map<String, ConditionalStage> conditionalStages;

  MonoConfig._(this.travis, this.conditionalStages);

  factory MonoConfig(Map travis) {
    final overlappingKeys =
        travis.keys.where(_reservedTravisKeys.contains).toList();
    if (overlappingKeys.isNotEmpty) {
      throw CheckedFromJsonException(travis, overlappingKeys.first.toString(),
          'MonoConfig', 'Contains illegal keys: ${overlappingKeys.join(', ')}');
    }

    final conditionalStages = <String, ConditionalStage>{};
    final rawStageValue = travis['stages'];
    if (rawStageValue != null) {
      if (rawStageValue is List) {
        for (var item in rawStageValue) {
          if (item is Map) {
            final stage = _$ConditionalStageFromJson(item);
            if (conditionalStages.containsKey(stage.name)) {
              throw CheckedFromJsonException(travis, 'stages', 'MonoConfig',
                  '`${stage.name}` appears more than once.');
            }
            conditionalStages[stage.name] = stage;
          } else {
            throw CheckedFromJsonException(travis, 'stages', 'MonoConfig',
                'All values must be Map instances.');
          }
        }
      } else {
        throw CheckedFromJsonException(
            travis, 'stages', 'MonoConfig', '`stages` must be an array.');
      }
    }

    // Removing this at the last minute so any throw CheckedFromJsonException
    // will have the right value
    // ... but the code that writes the values won't write stages seperately
    travis.remove('stages');

    return MonoConfig._(
        travis.map((k, v) => MapEntry(k as String, v)), conditionalStages);
  }

  factory MonoConfig.fromJson(Map json) {
    final nonTravisKeys = json.keys.where((k) => k != 'travis').toList();

    if (nonTravisKeys.isNotEmpty) {
      throw CheckedFromJsonException(json, nonTravisKeys.first as String,
          'MonoConfig', 'Only `travis` key is supported.');
    }

    final travis = json['travis'];

    if (travis is Map) {
      return MonoConfig(travis);
    }
    throw CheckedFromJsonException(
        json, 'travis', 'MonoConfig', '`travis` must be a Map.');
  }

  factory MonoConfig.fromRepo({String rootDirectory}) {
    rootDirectory ??= p.current;

    final yaml = yamlMapOrNull(rootDirectory, _monoConfigFileName);
    if (yaml == null || yaml.isEmpty) {
      return MonoConfig({});
    }

    try {
      return MonoConfig.fromJson(yaml);
    } on CheckedFromJsonException catch (e) {
      throw UserException('Error parsing $_monoConfigFileName',
          details: prettyPrintCheckedFromJsonException(e));
    }
  }
}

@JsonSerializable(disallowUnrecognizedKeys: true)
class ConditionalStage {
  @JsonKey(required: true, disallowNullValue: true)
  final String name;

  @JsonKey(name: 'if', required: true, disallowNullValue: true)
  final String ifCondition;

  ConditionalStage(this.name, this.ifCondition);

  Map<String, dynamic> toJson() => _$ConditionalStageToJson(this);
}
