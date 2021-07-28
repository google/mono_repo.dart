// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CIJob _$CIJobFromJson(Map json) => $checkedCreate(
      'CIJob',
      json,
      ($checkedConvert) {
        final val = CIJob(
          $checkedConvert('os', (v) => v as String),
          $checkedConvert('package', (v) => v as String),
          $checkedConvert('sdk', (v) => v as String),
          $checkedConvert('stageName', (v) => v as String),
          $checkedConvert(
              'tasks',
              (v) => (v as List<dynamic>)
                  .map(
                      (e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList()),
          description: $checkedConvert('description', (v) => v as String?),
        );
        return val;
      },
    );

Map<String, dynamic> _$CIJobToJson(CIJob instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('description', instance.description);
  val['os'] = instance.os;
  val['package'] = instance.package;
  val['sdk'] = instance.sdk;
  val['stageName'] = instance.stageName;
  val['tasks'] = instance.tasks.map((e) => e.toJson()).toList();
  return val;
}

Task _$TaskFromJson(Map json) => $checkedCreate(
      'Task',
      json,
      ($checkedConvert) {
        final val = Task(
          $checkedConvert('name', (v) => v as String),
          args: $checkedConvert('args', (v) => v as String?),
        );
        return val;
      },
    );

Map<String, dynamic> _$TaskToJson(Task instance) {
  final val = <String, dynamic>{
    'name': instance.name,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('args', instance.args);
  return val;
}
