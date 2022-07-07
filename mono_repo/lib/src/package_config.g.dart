// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: require_trailing_commas

part of 'package_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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
  val['flavor'] = _$PackageFlavorEnumMap[instance.flavor]!;
  return val;
}

const _$PackageFlavorEnumMap = {
  PackageFlavor.dart: 'dart',
  PackageFlavor.flutter: 'flutter',
};

Map<String, dynamic> _$TaskToJson(Task instance) {
  final val = <String, dynamic>{
    'flavor': _$PackageFlavorEnumMap[instance.flavor]!,
    'type': instance.type,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('args', instance.args);
  return val;
}
