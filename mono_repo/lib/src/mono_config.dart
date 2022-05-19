// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;

import 'github_config.dart';
import 'yaml.dart';

part 'mono_config.g.dart';

const _monoConfigFileName = 'mono_repo.yaml';

const _allowedMonoConfigKeys = {
  'github',
  'merge_stages',
  'pretty_ansi',
  'pub_action',
  'self_validate',
};

const _defaultPubAction = 'upgrade';

const _allowedPubActions = {
  'get',
  _defaultPubAction,
};

class MonoConfig {
  final Map<String, ConditionalStage> githubConditionalStages;
  final Set<String> mergeStages;
  final bool prettyAnsi;
  final String pubAction;
  final String? selfValidateStage;
  final GitHubConfig github;

  factory MonoConfig({
    required Set<String> mergeStages,
    required bool prettyAnsi,
    required String pubAction,
    required String? selfValidateStage,
    required Map github,
  }) {
    final githubConditionalStages = _readConditionalStages(github);

    return MonoConfig._(
      githubConditionalStages: githubConditionalStages,
      mergeStages: mergeStages,
      prettyAnsi: prettyAnsi,
      pubAction: pubAction,
      selfValidateStage: selfValidateStage,
      github: GitHubConfig.fromJson(github),
    );
  }

  MonoConfig._({
    required this.githubConditionalStages,
    required this.mergeStages,
    required this.prettyAnsi,
    required this.pubAction,
    required this.selfValidateStage,
    required this.github,
  });

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

      return value;
    }

    final github = parseCI(CI.github);

    final selfValidate = json['self_validate'] as Object? ?? false;
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
        mergeStages: Set.from(mergeStages),
        prettyAnsi: prettyAnsi,
        pubAction: pubAction,
        selfValidateStage: _selfValidateFromValue(selfValidate),
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

  factory MonoConfig.fromRepo({String? rootDirectory}) {
    rootDirectory ??= p.current;

    final yaml = yamlMapOrNull(rootDirectory, _monoConfigFileName);
    if (yaml == null || yaml.isEmpty) {
      return MonoConfig(
        mergeStages: <String>{},
        pubAction: _defaultPubAction,
        prettyAnsi: true,
        selfValidateStage: null,
        github: {},
      );
    }

    return createWithCheck(() => MonoConfig.fromJson(yaml));
  }
}

/// Parses the `stages` key from a CI config map, into a Map from stage name
/// to [ConditionalStage] instance.
Map<String, ConditionalStage> _readConditionalStages(
  Map<dynamic, dynamic> ciJson,
) {
  final conditionalStages = <String, ConditionalStage>{};
  final rawValue = ciJson['stages'];
  if (rawValue != null) {
    if (rawValue is List) {
      for (var item in rawValue) {
        if (item is Map || item is String) {
          final stage = ConditionalStage.fromJson(item as Object);
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

String? _selfValidateFromValue(Object? value) {
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
  final String? ifCondition;

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
}
