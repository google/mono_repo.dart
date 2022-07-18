// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

import '../../yaml.dart';
import 'overrides.dart';

part 'step.g.dart';

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
  constructor: '_',
)
class Step implements GitHubActionOverrides, YamlLike {
  @override
  final String? id;
  @override
  final String? name;
  @override
  final String? run;

  @override
  @JsonKey(name: 'if')
  final String? ifContent;

  @override
  @JsonKey(name: 'working-directory')
  final String? workingDirectory;

  @override
  final Map<String, String>? env;

  @override
  final String? uses;
  @override
  @JsonKey(name: 'with')
  final Map<String, dynamic>? withContent;

  @override
  final String? shell;

  @override
  @JsonKey(name: 'continue-on-error')
  final bool? continueOnError;

  @override
  @JsonKey(name: 'timeout-minutes')
  final int? timeoutMinutes;

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
    this.continueOnError,
    this.timeoutMinutes,
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

  factory Step.fromOverrides(GitHubActionOverrides overrides) {
    if (overrides.uses != null) {
      return Step._(
        id: overrides.id,
        name: overrides.name,
        uses: overrides.uses,
        withContent: overrides.withContent,
        ifContent: overrides.ifContent,
        continueOnError: overrides.continueOnError,
        timeoutMinutes: overrides.timeoutMinutes,
      );
    }
    return Step._(
      id: overrides.id,
      name: overrides.name,
      run: overrides.run,
      workingDirectory: overrides.workingDirectory,
      env: overrides.env,
      shell: overrides.shell,
      ifContent: overrides.ifContent,
      continueOnError: overrides.continueOnError,
      timeoutMinutes: overrides.timeoutMinutes,
    );
  }

  Step.run({
    this.id,
    required String this.name,
    required String this.run,
    this.ifContent,
    this.workingDirectory,
    this.env,
    this.shell,
    this.continueOnError,
    this.timeoutMinutes,
  })  : uses = null,
        withContent = null;

  Step.uses({
    this.id,
    required String this.name,
    required String this.uses,
    this.withContent,
    this.ifContent,
    this.continueOnError,
    this.timeoutMinutes,
  })  : run = null,
        env = null,
        workingDirectory = null,
        shell = null;

  factory Step.fromJson(Map json) => _$StepFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$StepToJson(this);
}
