// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: require_trailing_commas

part of 'mono_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConditionalStage _$ConditionalStageFromJson(Map json) => $checkedCreate(
      'ConditionalStage',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const ['name', 'if'],
          requiredKeys: const ['name', 'if'],
          disallowNullValues: const ['name', 'if'],
        );
        final val = ConditionalStage(
          $checkedConvert('name', (v) => v as String),
          $checkedConvert('if', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {'ifCondition': 'if'},
    );

Map<String, dynamic> _$ConditionalStageToJson(ConditionalStage instance) {
  final val = <String, dynamic>{
    'name': instance.name,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('if', instance.ifCondition);
  return val;
}
