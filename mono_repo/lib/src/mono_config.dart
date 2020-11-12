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
  'pretty_ansi',
  'self_validate',
  'travis',
  'ci',
};

const _defaultPubAction = 'upgrade';

const _allowedPubActions = {
  'get',
  _defaultPubAction,
};

class MonoConfig {
  final List<CI> ci;
  final Map<String, ConditionalStage> conditionalStages;
  final Set<String> mergeStages;
  final bool prettyAnsi;
  final String pubAction;
  final String selfValidateStage;
  final Map<String, dynamic> travis;

  MonoConfig._({
    @required this.ci,
    @required this.conditionalStages,
    @required this.mergeStages,
    @required this.prettyAnsi,
    @required this.pubAction,
    @required this.selfValidateStage,
    @required this.travis,
  });

  factory MonoConfig({
    @required List<CI> ci,
    @required Set<String> mergeStages,
    @required bool prettyAnsi,
    @required String pubAction,
    @required String selfValidateStage,
    @required Map travis,
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

    return MonoConfig._(
      ci: ci,
      conditionalStages: conditionalStages,
      mergeStages: mergeStages,
      prettyAnsi: prettyAnsi,
      pubAction: pubAction,
      selfValidateStage: selfValidateStage,
      // Removing 'stages' so any `throw CheckedFromJsonException` will have the
      // right value, but the code that writes the values won't write stages
      // separately
      travis: travis.map((k, v) => MapEntry(k as String, v))..remove('stages'),
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
    if (selfValidate is! bool && selfValidate is! String) {
      throw CheckedFromJsonException(
        json,
        'self_validate',
        'MonoConfig',
        'Value must be `true`, `false`, or a stage name.',
      );
    }

    final prettyAnsi = json['pretty_ansi'] ?? true;
    if (prettyAnsi is! bool) {
      throw CheckedFromJsonException(
        json,
        'pretty_ansi',
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

    final ci = (Object ci) {
      ci ??= ['travis'];
      if (ci is! List) {
        throw CheckedFromJsonException(
          json,
          'ci',
          'MonoConfig',
          'Value must be a List of Strings matching either "github" or '
              '"travis".',
        );
      }
      final parsed = <CI>[];
      for (var entry in ci as List<Object>) {
        if (entry is! String) {
          throw CheckedFromJsonException(
            json,
            'ci',
            'MonoConfig',
            'Value must be Strings matching either "github" or "travis".',
          );
        }
        switch (entry as String) {
          case 'travis':
            parsed.add(CI.travis);
            break;
          case 'github':
            parsed.add(CI.github);
            break;
          default:
            throw ArgumentError.value(
                entry, 'ci', 'Only "github" and "travis" are allowed');
        }
      }
      return parsed;
    }(json['ci']);

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
        ci: ci,
        mergeStages: Set.from(mergeStages),
        prettyAnsi: prettyAnsi as bool,
        pubAction: pubAction as String,
        selfValidateStage: _selfValidateFromValue(selfValidate),
        travis: travis as Map,
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
        ci: null,
        mergeStages: <String>{},
        pubAction: _defaultPubAction,
        prettyAnsi: true,
        selfValidateStage: null,
        travis: {},
      );
    }

    return createWithCheck(() => MonoConfig.fromJson(yaml));
  }
}

const _selfValidateStageName = 'mono_repo_self_validate';

String _selfValidateFromValue(Object value) {
  if (value == null) return null;
  if (value is bool) return value ? _selfValidateStageName : null;
  if (value is String) return value;
  throw ArgumentError.value(value, 'value', 'Must be a `String` or `bool`.');
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

// The available CI providers that we generate config for.
enum CI {
  github,
  travis,
}
