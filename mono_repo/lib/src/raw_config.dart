// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

part 'raw_config.g.dart';

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class RawConfig {
  @JsonKey(name: 'dart')
  final List<String> sdks;

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
      throw new CheckedFromJsonException(
          json, 'dart', 'RawConfig', 'The "dart" key is required.');
    }

    var config = _$RawConfigFromJson(json);

    var stages = new Set<String>();
    for (var i = 0; i < config.stages.length; i++) {
      var name = config.stages[i].name;
      if (!stages.add(name)) {
        var map = (json['stages'] as List)[i] as Map;

        throw new CheckedFromJsonException(map, name, 'RawStage',
            'Stages muts be unique. "$name" appears more than once.');
      }
    }

    return config;
  }
}

class RawStage {
  final String name;
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
    if (items.isEmpty) {
      throw new ArgumentError.value(items, name,
          'Stages are required to have at least one job. "$name" is empty.');
    }
  }

  factory RawStage.fromJson(Map json) {
    if (json.isEmpty) {
      throw new CheckedFromJsonException(
          json,
          null,
          'RawStage',
          '`stages` expects a list of maps with exactly one key '
          '(the name of the stage), but no items exist.');
    }
    if (json.length > 1) {
      throw new CheckedFromJsonException(
          json,
          json.keys.skip(1).first.toString(),
          'RawStage',
          '`stages` expects a list of maps with exactly one key (the name of '
          'the stage), but the provided value has ${json.length} values.');
    }

    var entry = json.entries.single;

    var name = entry.key as String;
    if (entry.value == null) {
      throw new CheckedFromJsonException(json, name, 'RawStage',
          'Stages are required to have at least one job. "$name" is null.');
    }
    if (entry.value is! List) {
      throw new CheckedFromJsonException(
          json,
          name,
          'RawStage',
          '`stages` expects a list of maps with exactly one key (the name of '
          'the stage). The provided value `$json` is not valid.');
    }

    try {
      return new RawStage(entry.key as String, entry.value as List);
    } on ArgumentError catch (error) {
      throw new CheckedFromJsonException(
          json, error.name, 'RawStage', error.message?.toString());
    }
  }

  @override
  String toString() => '{$name: $items}';
}
