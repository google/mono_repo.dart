// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: prefer_expression_function_bodies

part of 'mono_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConditionalStage _$ConditionalStageFromJson(Map json) {
  return $checkedNew('ConditionalStage', json, () {
    $checkKeys(json,
        allowedKeys: const ['name', 'if'],
        requiredKeys: const ['name', 'if'],
        disallowNullValues: const ['name', 'if']);
    final val = ConditionalStage(
      $checkedConvert(json, 'name', (v) => v as String),
      $checkedConvert(json, 'if', (v) => v as String),
    );
    return val;
  }, fieldKeyMap: const {'ifCondition': 'if'});
}

Map<String, dynamic> _$ConditionalStageToJson(ConditionalStage instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('if', instance.ifCondition);
  return val;
}
