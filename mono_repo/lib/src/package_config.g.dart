// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TravisJob _$TravisJobFromJson(Map json) {
  return $checkedNew('TravisJob', json, () {
    final val = TravisJob(
        $checkedConvert(json, 'package', (v) => v as String),
        $checkedConvert(json, 'sdk', (v) => v as String),
        $checkedConvert(json, 'stageName', (v) => v as String),
        $checkedConvert(
            json,
            'tasks',
            (v) => (v as List)
                ?.map((e) => e == null
                    ? null
                    : Task.fromJson((e as Map)?.map(
                        (k, e) => MapEntry(k as String, e),
                      )))
                ?.toList()),
        description: $checkedConvert(json, 'description', (v) => v as String));
    return val;
  });
}

Map<String, dynamic> _$TravisJobToJson(TravisJob instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('description', instance.description);
  val['package'] = instance.package;
  val['sdk'] = instance.sdk;
  val['stageName'] = instance.stageName;
  val['tasks'] = instance.tasks;
  return val;
}

Task _$TaskFromJson(Map json) {
  return $checkedNew('Task', json, () {
    final val = Task($checkedConvert(json, 'name', (v) => v as String),
        args: $checkedConvert(json, 'args', (v) => v as String),
        config: $checkedConvert(
            json,
            'config',
            (v) => (v as Map)?.map(
                  (k, e) => MapEntry(k as String, e),
                )));
    return val;
  });
}

Map<String, dynamic> _$TaskToJson(Task instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('args', instance.args);
  writeNotNull('config', instance.config);
  return val;
}
