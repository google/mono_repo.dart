// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mono_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConditionalStage _$ConditionalStageFromJson(Map json) {
  return $checkedNew('ConditionalStage', json, () {
    $checkKeys(json,
        allowedKeys: ['name', 'if'],
        requiredKeys: ['name', 'if'],
        disallowNullValues: ['name', 'if']);
    var val = ConditionalStage(
        $checkedConvert(json, 'name', (v) => v as String),
        $checkedConvert(json, 'if', (v) => v as String));
    return val;
  }, fieldKeyMap: {'ifCondition': 'if'});
}

Map<String, dynamic> _$ConditionalStageToJson(ConditionalStage instance) {
  var val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('if', instance.ifCondition);
  return val;
}
