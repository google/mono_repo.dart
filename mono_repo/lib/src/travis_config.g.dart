// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of mono_repo.travis_config;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

TravisConfig _$TravisConfigFromJson(Map<String, dynamic> json) =>
    new TravisConfig(
        (json['sdks'] as List)?.map((e) => e as String)?.toList(),
        (json['tasks'] as List)
            ?.map((e) => e == null
                ? null
                : new DartTask.fromJson(e as Map<String, dynamic>))
            ?.toList(),
        (json['include'] as List)
            ?.map((e) => e == null
                ? null
                : new TravisJob.fromJson(e as Map<String, dynamic>))
            ?.toList(),
        (json['exclude'] as List)
            ?.map((e) => e == null
                ? null
                : new TravisJob.fromJson(e as Map<String, dynamic>))
            ?.toList(),
        (json['allowFailures'] as List)
            ?.map((e) => e == null
                ? null
                : new TravisJob.fromJson(e as Map<String, dynamic>))
            ?.toList(),
        json['beforeScript'] as String);

abstract class _$TravisConfigSerializerMixin {
  List<String> get sdks;
  List<DartTask> get tasks;
  List<TravisJob> get include;
  List<TravisJob> get exclude;
  List<TravisJob> get allowFailures;
  String get beforeScript;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'sdks': sdks,
        'tasks': tasks,
        'include': include,
        'exclude': exclude,
        'allowFailures': allowFailures,
        'beforeScript': beforeScript
      };
}

TravisJob _$TravisJobFromJson(Map<String, dynamic> json) => new TravisJob(
    json['sdk'] as String,
    json['task'] == null
        ? null
        : new DartTask.fromJson(json['task'] as Map<String, dynamic>));

abstract class _$TravisJobSerializerMixin {
  String get sdk;
  DartTask get task;
  Map<String, dynamic> toJson() => <String, dynamic>{'sdk': sdk, 'task': task};
}

DartTask _$DartTaskFromJson(Map<String, dynamic> json) =>
    new DartTask(json['name'] as String,
        args: json['args'] as String,
        config: json['config'] as Map<String, dynamic>);

abstract class _$DartTaskSerializerMixin {
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
