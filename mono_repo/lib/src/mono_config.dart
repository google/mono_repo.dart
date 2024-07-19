// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;

import 'basic_config.dart';
import 'coverage_processor.dart';
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
  'coverage_service',
};

const _defaultPubAction = 'upgrade';

const _allowedPubActions = {
  'get',
  _defaultPubAction,
};

class MonoConfig implements BasicConfiguration {
  final Map<String, ConditionalStage> githubConditionalStages;
  final Set<String> mergeStages;
  final bool prettyAnsi;
  final String pubAction;
  final String? selfValidateStage;
  final GitHubConfig github;
  @override
  final Set<CoverageProcessor> coverageProcessors;

  MonoConfig._({
    required this.mergeStages,
    required this.prettyAnsi,
    required this.pubAction,
    required this.selfValidateStage,
    required Map github,
    required this.coverageProcessors,
  })  : githubConditionalStages = _readConditionalStages(github),
        github = GitHubConfig.fromJson(github);

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
      final value = json[key] ?? <String, dynamic>{};

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

    final mergeStages = _asList(json, 'merge_stages');

    final coverageServices = _asList(json, 'coverage_service');

    return MonoConfig._(
      mergeStages: Set.from(mergeStages),
      prettyAnsi: prettyAnsi,
      pubAction: pubAction,
      selfValidateStage: _selfValidateFromValue(selfValidate),
      github: github,
      coverageProcessors: coverageServices
          .map((e) => CoverageProcessor.values.byName(e))
          .toSet(),
    );
  }

  factory MonoConfig.fromRepo({String? rootDirectory}) {
    rootDirectory ??= p.current;

    final yaml = yamlMapOrNull(rootDirectory, _monoConfigFileName);
    if (yaml == null || yaml.isEmpty) {
      return MonoConfig._(
        mergeStages: <String>{},
        pubAction: _defaultPubAction,
        prettyAnsi: true,
        selfValidateStage: null,
        github: {},
        coverageProcessors: {CoverageProcessor.coveralls},
      );
    }

    return createWithCheck(() => MonoConfig.fromJson(yaml));
  }
}

List<String> _asList(Map json, String key) {
  final value = json[key] ?? <String>[];

  if (value is List) {
    if (value.any((v) => v is! String)) {
      throw CheckedFromJsonException(
        json,
        key,
        'MonoConfig',
        'All values must be strings.',
      );
    }
    return List.from(value);
  }
  throw CheckedFromJsonException(
    json,
    key,
    'MonoConfig',
    '`$key` must be an array.',
  );
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

@JsonSerializable(
  createToJson: false,
  disallowUnrecognizedKeys: true,
)
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
}

// The available CI providers that we generate config for.
enum CI {
  github,
}
