// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

import '../../yaml.dart';

part 'step.g.dart';

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
  constructor: '_',
)
class Step implements YamlLike {
  final String? id;
  final String? name;
  final String? run;

  @JsonKey(name: 'if')
  final String? ifContent;
  @JsonKey(name: 'working-directory')
  final String? workingDirectory;

  final Map? env;

  final String? uses;
  @JsonKey(name: 'with')
  final Map? withContent;

  final String? shell;

  Step._({
    this.id,
    this.withContent,
    this.name,
    this.uses,
    this.run,
    this.ifContent,
    this.workingDirectory,
    this.env,
    this.shell,
  }) {
    if (run == null) {
      if (uses == null) {
        throw ArgumentError.value(
          uses,
          'uses',
          'Either `run` or `uses` must be defined.',
        );
      }
    } else {
      if (uses != null) {
        throw ArgumentError.value(
          uses,
          'uses',
          '`uses` and `run` cannot both be defined.',
        );
      } else if (withContent != null) {
        throw ArgumentError.value(
          withContent,
          'withContent',
          '`withContent` cannot be defined unless `uses` is defined.`',
        );
      }
    }
  }

  Step.run({
    this.id,
    required String this.name,
    required this.run,
    this.ifContent,
    this.workingDirectory,
    this.env,
    this.shell,
  })  : uses = null,
        withContent = null;

  Step.uses({
    this.id,
    required String this.name,
    required this.uses,
    this.withContent,
    this.ifContent,
  })  : run = null,
        env = null,
        workingDirectory = null,
        shell = null;

  factory Step.fromJson(Map json) => _$StepFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$StepToJson(this);
}
