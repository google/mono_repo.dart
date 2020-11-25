// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'github_config.dart';
import 'yaml.dart';

part 'mono_config.g.dart';

const _monoConfigFileName = 'mono_repo.yaml';

/// The top-level keys that cannot be set under `travis:` in  `mono_repo.yaml`
const _reservedTravisKeys = {'cache', 'jobs', 'language'};

const _allowedMonoConfigKeys = {
  'github',
  'merge_stages',
  'pretty_ansi',
  'pub_action',
  'self_validate',
  'travis',
};

const _defaultPubAction = 'upgrade';

const _allowedPubActions = {
  'get',
  _defaultPubAction,
};

class MonoConfig {
  final Set<CI> ci;
  final Map<String, ConditionalStage> githubConditionalStages;
  final Map<String, ConditionalStage> travisConditionalStages;
  final Set<String> mergeStages;
  final bool prettyAnsi;
  final String pubAction;
  final String selfValidateStage;
  final Map<String, dynamic> travis;
  final GitHubConfig github;

  MonoConfig._({
    @required Set<CI> ci,
    @required this.githubConditionalStages,
    @required this.travisConditionalStages,
    @required this.mergeStages,
    @required this.prettyAnsi,
    @required this.pubAction,
    @required this.selfValidateStage,
    @required this.travis,
    @required this.github,
  }) : ci = ci ?? const {CI.travis};

  factory MonoConfig({
    @required Set<CI> ci,
    @required Set<String> mergeStages,
    @required bool prettyAnsi,
    @required String pubAction,
    @required String selfValidateStage,
    @required Map travis,
    @required Map github,
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

    final githubConditionalStages = _readConditionalStages(github);
    final travisConditionalStages = _readConditionalStages(travis);

    return MonoConfig._(
      ci: ci,
      githubConditionalStages: githubConditionalStages,
      travisConditionalStages: travisConditionalStages,
      mergeStages: mergeStages,
      prettyAnsi: prettyAnsi,
      pubAction: pubAction,
      selfValidateStage: selfValidateStage,
      travis: travis.map((k, v) => MapEntry(k as String, v)),
      github: GitHubConfig.fromJson(github),
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

    final ci = {
      if (json.containsKey('travis')) CI.travis,
      if (json.containsKey('github')) CI.github,
    };

    Map parseCI(CI targetCI) {
      final key = targetCI.toString().split('.').last;
      final value = json[key] ?? {};

      if (value is bool) {
        if (!value) {
          ci.remove(targetCI);
        }
        return {};
      } else if (value is! Map) {
        throw CheckedFromJsonException(
          json,
          key,
          'MonoConfig',
          '`$key` must be a Map.',
        );
      }

      return value as Map;
    }

    final travis = parseCI(CI.travis);
    final github = parseCI(CI.github);

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
        travis: travis,
        github: github,
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
        github: {},
      );
    }

    return createWithCheck(() => MonoConfig.fromJson(yaml));
  }
}

/// Parses the `stages` key from a CI config map, into a Map from stage name
/// to [ConditionalStage] instance.
Map<String, ConditionalStage> _readConditionalStages(
    Map<dynamic, dynamic> ciJson) {
  final conditionalStages = <String, ConditionalStage>{};
  final rawValue = ciJson['stages'];
  if (rawValue != null) {
    if (rawValue is List) {
      for (var item in rawValue) {
        if (item is Map || item is String) {
          final stage = ConditionalStage.fromJson(item);
          if (conditionalStages.containsKey(stage.name)) {
            throw CheckedFromJsonException(
              ciJson,
              'stages',
              'MonoConfig',
              '`${stage.name}` appears more than once.',
            );
          }
          conditionalStages[stage.name] = stage;
        } else {
          throw CheckedFromJsonException(
            ciJson,
            'stages',
            'MonoConfig',
            'All values must be String or Map instances.',
          );
        }
      }
    } else {
      throw CheckedFromJsonException(
        ciJson,
        'stages',
        'MonoConfig',
        '`stages` must be an array.',
      );
    }
  }
  return conditionalStages;
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
