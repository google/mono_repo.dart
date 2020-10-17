// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'yaml.dart';

part 'mono_config.g.dart';

const _monoConfigFileName = 'mono_repo.yaml';

/// The top-level keys that cannot be set under `travis:` in  `mono_repo.yaml`
const _reservedTravisKeys = {'cache', 'jobs', 'language'};

const _allowedMonoConfigKeys = {
  'pub_action',
  'merge_stages',
  'self_validate',
  'travis',
};

const _defaultPubAction = 'upgrade';

const _allowedPubActions = {
  'get',
  _defaultPubAction,
};

class MonoConfig {
  final String pubAction;
  final bool selfValidate;
  final Map<String, dynamic> travis;
  final Map<String, ConditionalStage> conditionalStages;
  final Set<String> mergeStages;

  MonoConfig._({
    @required this.pubAction,
    @required this.travis,
    @required this.conditionalStages,
    @required this.mergeStages,
    @required this.selfValidate,
  });

  factory MonoConfig({
    @required Map travis,
    @required Set<String> mergeStages,
    @required bool selfValidate,
    @required String pubAction,
  }) {
    final overlappingKeys =
        travis.keys.where(_reservedTravisKeys.contains).toList();
    if (overlappingKeys.isNotEmpty) {
      throw CheckedFromJsonException(
        travis,
        overlappingKeys.first.toString(),
        'MonoConfig',
        'Contains illegal keys: ${overlappingKeys.join(', ')}',
      );
    }

    final conditionalStages = <String, ConditionalStage>{};
    final rawStageValue = travis['stages'];
    if (rawStageValue != null) {
      if (rawStageValue is List) {
        for (var item in rawStageValue) {
          if (item is Map || item is String) {
            final stage = ConditionalStage.fromJson(item);
            if (conditionalStages.containsKey(stage.name)) {
              throw CheckedFromJsonException(
                travis,
                'stages',
                'MonoConfig',
                '`${stage.name}` appears more than once.',
              );
            }
            conditionalStages[stage.name] = stage;
          } else {
            throw CheckedFromJsonException(
              travis,
              'stages',
              'MonoConfig',
              'All values must be String or Map instances.',
            );
          }
        }
      } else {
        throw CheckedFromJsonException(
          travis,
          'stages',
          'MonoConfig',
          '`stages` must be an array.',
        );
      }
    }

    // Removing this at the last minute so any throw CheckedFromJsonException
    // will have the right value
    // ... but the code that writes the values won't write stages separately
    travis.remove('stages');

    return MonoConfig._(
      travis: travis.map((k, v) => MapEntry(k as String, v)),
      conditionalStages: conditionalStages,
      mergeStages: mergeStages,
      selfValidate: selfValidate,
      pubAction: pubAction,
    );
  }

  factory MonoConfig.fromJson(Map json) {
    final unsupportedKeys =
        json.keys.where((k) => !_allowedMonoConfigKeys.contains(k)).toList();

    if (unsupportedKeys.isNotEmpty) {
      throw CheckedFromJsonException(
        json,
        unsupportedKeys.first as String,
        'MonoConfig',
        'Only ${_allowedMonoConfigKeys.map((s) => '`$s`').join(', ')} keys '
            'are supported.',
      );
    }

    final travis = json['travis'] ?? {};

    if (travis is! Map) {
      throw CheckedFromJsonException(
        json,
        'travis',
        'MonoConfig',
        '`travis` must be a Map.',
      );
    }

    final selfValidate = json['self_validate'] ?? false;
    if (selfValidate is! bool) {
      throw CheckedFromJsonException(
        json,
        'self_validate',
        'MonoConfig',
        'Value must be `true` or `false`.',
      );
    }

    final pubAction = json['pub_action'] ?? _defaultPubAction;
    if (pubAction is! String || !_allowedPubActions.contains(pubAction)) {
      final allowed = _allowedPubActions.map((e) => '`$e`').join(', ');
      throw CheckedFromJsonException(
        json,
        'pub_action',
        'MonoConfig',
        'Value must be one of: $allowed.',
      );
    }

    final mergeStages = json['merge_stages'] ?? [];

    if (mergeStages is List) {
      if (mergeStages.any((v) => v is! String)) {
        throw CheckedFromJsonException(
          json,
          'merge_stages',
          'MonoConfig',
          'All values must be strings.',
        );
      }

      return MonoConfig(
        travis: travis as Map,
        mergeStages: Set.from(mergeStages),
        selfValidate: selfValidate as bool,
        pubAction: pubAction as String,
      );
    } else {
      throw CheckedFromJsonException(
        json,
        'merge_stages',
        'MonoConfig',
        '`merge_stages` must be an array.',
      );
    }
  }

  factory MonoConfig.fromRepo({String rootDirectory}) {
    rootDirectory ??= p.current;

    final yaml = yamlMapOrNull(rootDirectory, _monoConfigFileName);
    if (yaml == null || yaml.isEmpty) {
      return MonoConfig(
        travis: {},
        mergeStages: <String>{},
        selfValidate: false,
        pubAction: _defaultPubAction,
      );
    }

    return createWithCheck(() => MonoConfig.fromJson(yaml));
  }
}

@JsonSerializable(disallowUnrecognizedKeys: true)
class ConditionalStage {
  @JsonKey(required: true, disallowNullValue: true)
  final String name;

  @JsonKey(name: 'if', required: true, disallowNullValue: true)
  final String ifCondition;

  ConditionalStage(this.name, [this.ifCondition]);

  factory ConditionalStage.fromJson(Object json) {
    if (json is String) {
      return ConditionalStage(json);
    }
    return _$ConditionalStageFromJson(json as Map);
  }

  Object toJson() {
    if (ifCondition == null) {
      return name;
    }
    return _$ConditionalStageToJson(this);
  }
}
