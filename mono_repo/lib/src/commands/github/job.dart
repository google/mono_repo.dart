// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

import '../../yaml.dart';
import 'step.dart';

part 'job.g.dart';

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
)
class Job implements YamlLike {
  final String? name;

  @JsonKey(name: 'runs-on')
  final String? runsOn;

  @JsonKey(name: 'if')
  String? ifContent;

  @JsonKey(required: true)
  final List<Step> steps;

  List<String>? needs;

  Map<String, String>? outputs;

  Map<String, String>? permissions;

  Job({
    this.name,
    this.runsOn,
    required this.steps,
    this.ifContent,
    this.needs,
    this.outputs,
    this.permissions,
  });

  factory Job.fromJson(Map json) => _$JobFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$JobToJson(this);
}
