// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: require_trailing_commas

part of 'package_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$CIJobToJson(CIJob instance) => <String, dynamic>{
      if (instance.description case final value?) 'description': value,
      'os': instance.os,
      'package': instance.package,
      'sdk': instance.sdk,
      'stageName': instance.stageName,
      'tasks': instance.tasks.map((e) => e.toJson()).toList(),
      'flavor': _$PackageFlavorEnumMap[instance.flavor]!,
    };

const _$PackageFlavorEnumMap = {
  PackageFlavor.dart: 'dart',
  PackageFlavor.flutter: 'flutter',
};

Map<String, dynamic> _$TaskToJson(Task instance) => <String, dynamic>{
      'flavor': _$PackageFlavorEnumMap[instance.flavor]!,
      'type': instance.type,
      if (instance.args case final value?) 'args': value,
    };
