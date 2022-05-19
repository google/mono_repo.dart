// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: require_trailing_commas

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
          flavor: $checkedConvert(
              'flavor', (v) => $enumDecode(_$PackageFlavorEnumMap, v)),
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
  val['flavor'] = _$PackageFlavorEnumMap[instance.flavor];
  return val;
}

const _$PackageFlavorEnumMap = {
  PackageFlavor.dart: 'dart',
  PackageFlavor.flutter: 'flutter',
};

Task _$TaskFromJson(Map json) => $checkedCreate(
      'Task',
      json,
      ($checkedConvert) {
        final val = Task(
          $checkedConvert(
              'flavor', (v) => $enumDecode(_$PackageFlavorEnumMap, v)),
          $checkedConvert('name', (v) => v as String),
          args: $checkedConvert('args', (v) => v as String?),
        );
        return val;
      },
    );

Map<String, dynamic> _$TaskToJson(Task instance) {
  final val = <String, dynamic>{
    'flavor': _$PackageFlavorEnumMap[instance.flavor],
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
