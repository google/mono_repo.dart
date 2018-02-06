// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of mono_repo.travis_config;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

MonoConfig _$MonoConfigFromJson(Map<String, dynamic> json) => new MonoConfig(
    (json['sdks'] as List)?.map((e) => e as String)?.toList(),
    (json['stageNames'] as List)?.map((e) => e as String)?.toList(),
    (json['jobs'] as List)
        ?.map((e) => e == null
            ? null
            : new TravisJob.fromJson(e as Map<String, dynamic>))
        ?.toList());

abstract class _$MonoConfigSerializerMixin {
  List<String> get sdks;
  List<String> get stageNames;
  List<TravisJob> get jobs;
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'sdks': sdks, 'stageNames': stageNames, 'jobs': jobs};
}

TravisJob _$TravisJobFromJson(Map<String, dynamic> json) => new TravisJob(
    json['package'] as String,
    json['sdk'] as String,
    json['stageName'] as String,
    json['task'] == null
        ? null
        : new Task.fromJson(json['task'] as Map<String, dynamic>));

abstract class _$TravisJobSerializerMixin {
  String get package;
  String get sdk;
  String get stageName;
  Task get task;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'package': package,
        'sdk': sdk,
        'stageName': stageName,
        'task': task
      };
}

Task _$TaskFromJson(Map<String, dynamic> json) =>
    new Task(json['name'] as String,
        args: json['args'] as String,
        config: json['config'] as Map<String, dynamic>);

abstract class _$TaskSerializerMixin {
  String get name;
  String get args;
  Map<String, dynamic> get config;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('name', name);
    writeNotNull('args', args);
    writeNotNull('config', config);
    return val;
  }
}
