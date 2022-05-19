// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:json_annotation/json_annotation.dart';

import 'package_config.dart';
import 'utilities.dart';

part 'raw_config.g.dart';

@JsonSerializable(createToJson: false, disallowUnrecognizedKeys: true)
class RawConfig {
  @JsonKey(name: 'os', defaultValue: ['linux'])
  final List<String> oses;

  @JsonKey(name: 'sdk')
  final List<String>? sdks;

  final List<RawStage> stages;

  final RawCache? cache;

  RawConfig({
    required this.oses,
    this.sdks,
    List<RawStage>? stages,
    this.cache,
  }) : stages = stages ??
            [
              RawStage('unit_test', ['test'])
            ] {
    if (sdks != null) {
      sortNormalizeVerifySdksList(
        Zone.current[_flavorKey] as PackageFlavor,
        sdks!,
        (m) => ArgumentError.value(sdks, 'sdks', m),
      );
    }
    oses.sort();
  }

  factory RawConfig.fromYaml(PackageFlavor flavor, Map json) {
    final config = runZoned(
      () => _$RawConfigFromJson(json),
      zoneValues: {_flavorKey: flavor},
    );

    final stages = <String>{};
    for (var i = 0; i < config.stages.length; i++) {
      final name = config.stages[i].name;
      if (!stages.add(name)) {
        final map = (json['stages'] as List)[i] as Map;

        throw CheckedFromJsonException(
          map,
          name,
          'RawStage',
          'Stages must be unique. "$name" appears more than once.',
          badKey: true,
        );
      }
    }

    return config;
  }

  static final _flavorKey = Object();
}

@JsonSerializable(createToJson: false)
class RawCache {
  final List<String> directories;

  RawCache(this.directories);

  factory RawCache.fromJson(Map json) => _$RawCacheFromJson(json);
}

class RawStage {
  static const _stageErrorPrefix =
      'Stages must be a list of maps with exactly one key '
      '(the name of the stage), but';

  final String name;
  final List items;

  RawStage(this.name, this.items) {
    if (items.isEmpty) {
      throw ArgumentError.value(
        items,
        name,
        'Stages are required to have at least one job. "$name" is empty.',
      );
    }
  }

  factory RawStage.fromJson(Map json) {
    if (json.isEmpty) {
      throw CheckedFromJsonException(
        json,
        null,
        'RawStage',
        '$_stageErrorPrefix no items exist.',
        badKey: true,
      );
    }
    if (json.length > 1) {
      throw CheckedFromJsonException(
        json,
        json.keys.skip(1).first.toString(),
        'RawStage',
        '$_stageErrorPrefix the provided value has ${json.length} values.',
        badKey: true,
      );
    }

    final entry = json.entries.single;

    final name = entry.key as String;
    if (entry.value == null) {
      throw CheckedFromJsonException(
        json,
        name,
        'RawStage',
        'Stages are required to have at least one job. "$name" is null.',
      );
    }
    if (entry.value is! List) {
      throw CheckedFromJsonException(
        json,
        name,
        'RawStage',
        '$_stageErrorPrefix the provided value `$json` is not valid.',
      );
    }

    try {
      return RawStage(entry.key as String, entry.value as List);
    } on ArgumentError catch (error) // ignore: avoid_catching_errors
    {
      throw CheckedFromJsonException(
        json,
        error.name,
        'RawStage',
        error.message?.toString(),
      );
    }
  }

  @override
  String toString() => '{$name: $items}';
}
