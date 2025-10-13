// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: require_trailing_commas

part of 'job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Job _$JobFromJson(Map json) => $checkedCreate('Job', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['steps']);
  final val = Job(
    name: $checkedConvert('name', (v) => v as String?),
    runsOn: $checkedConvert('runs-on', (v) => v as String?),
    steps: $checkedConvert(
      'steps',
      (v) => (v as List<dynamic>).map((e) => Step.fromJson(e as Map)).toList(),
    ),
  );
  $checkedConvert('if', (v) => val.ifContent = v as String?);
  $checkedConvert(
    'needs',
    (v) => val.needs = (v as List<dynamic>?)?.map((e) => e as String).toList(),
  );
  return val;
}, fieldKeyMap: const {'runsOn': 'runs-on', 'ifContent': 'if'});

Map<String, dynamic> _$JobToJson(Job instance) => <String, dynamic>{
  'name': ?instance.name,
  'runs-on': ?instance.runsOn,
  'if': ?instance.ifContent,
  'steps': instance.steps.map((e) => e.toJson()).toList(),
  'needs': ?instance.needs,
};
