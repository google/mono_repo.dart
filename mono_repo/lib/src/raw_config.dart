// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

part 'raw_config.g.dart';

@JsonSerializable()
class RawConfig extends Object with _$RawConfigSerializerMixin {
  @override
  @JsonKey(name: 'dart')
  final List<String> sdks;

  @override
  final List<RawStage> stages;

  RawConfig(this.sdks, List<RawStage> stages)
      : this.stages = stages ??
            [
              new RawStage('unit_test', ['test'])
            ] {
    if (sdks == null || sdks.isEmpty) {
      throw new ArgumentError.value(
          null, 'sdks', 'The "dart" key must have at least one value.');
    }
  }

  factory RawConfig.fromJson(Map json) {
    if (!json.containsKey('dart')) {
      throw new ArgumentError('The "dart" key is required.');
    }

    var unrecognizedKeys = (json.keys.toSet()..removeAll(_validKeys)).toList()
      ..sort();

    if (unrecognizedKeys.isNotEmpty) {
      throw new ArgumentError(
          'Unrecognized keys $unrecognizedKeys in .mono_repo.yaml.'
          'Only $_validKeys are allowed.');
    }

    var config = _$RawConfigFromJson(json);

    var stages = new Set<String>();
    for (var i = 0; i < config.stages.length; i++) {
      var name = config.stages[i].name;
      if (!stages.add(name)) {
        var map = (json['stages'] as List)[i] as Map;

        // TODO: need ctor for CheckedFromJsonException
        // https://github.com/dart-lang/json_serializable/issues/187
        return $checkedNew(
            'RawConfig',
            map,
            () => throw new ArgumentError.value(null, name,
                'Stages muts be unique. "$name" appears more than once.'));
      }
    }

    return config;
  }

  static final _validKeys = const [
    'dart',
    'stages',
  ];
}

@JsonSerializable(createFactory: false)
class RawStage extends Object with _$RawStageSerializerMixin {
  @override
  final String name;
  @override
  final List items;

  RawStage(this.name, this.items) {
    // NOTE: If ArgumentError is throw, intentionally using the value of `name`
    // (and not "name", as you'd expect) because it corresponds to the
    // `key` in the config map we'd like the error reported on
    if (name == 'test') {
      throw new ArgumentError.value(
          name,
          name,
          'Stages are not allowed to have the name `test` because it '
          'interacts poorly with the default stage by the same name.');
    }
    if (items == null) {
      throw new ArgumentError.value(items, name,
          'Stages are required to have at least one job. "$name" is null.');
    }
    if (items.isEmpty) {
      throw new ArgumentError.value(items, name,
          'Stages are required to have at least one job. "$name" is empty.');
    }
  }

  factory RawStage.fromJson(Map json) {
    if (json.length != 1) {
      throw new ArgumentError(
          '`stages` expects a list of maps with exactly one key '
          '(the name of the stage). Got $json.');
    }

    var entry = json.entries.single;

    // TODO: need ctor for CheckedFromJsonException
    // https://github.com/dart-lang/json_serializable/issues/187
    return $checkedNew('RawStage', json,
        () => new RawStage(entry.key as String, entry.value as List));
  }

  @override
  String toString() => '{$name: $items}';
}
