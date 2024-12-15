// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: require_trailing_commas

part of 'job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Job _$JobFromJson(Map json) => $checkedCreate(
      'Job',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['steps'],
        );
        final val = Job(
          name: $checkedConvert('name', (v) => v as String?),
          runsOn: $checkedConvert('runs-on', (v) => v as String?),
          steps: $checkedConvert(
              'steps',
              (v) => (v as List<dynamic>)
                  .map((e) => Step.fromJson(e as Map))
                  .toList()),
        );
        $checkedConvert('if', (v) => val.ifContent = v as String?);
        $checkedConvert(
            'needs',
            (v) => val.needs =
                (v as List<dynamic>?)?.map((e) => e as String).toList());
        return val;
      },
      fieldKeyMap: const {'runsOn': 'runs-on', 'ifContent': 'if'},
    );

Map<String, dynamic> _$JobToJson(Job instance) => <String, dynamic>{
      if (instance.name case final value?) 'name': value,
      if (instance.runsOn case final value?) 'runs-on': value,
      if (instance.ifContent case final value?) 'if': value,
      'steps': instance.steps.map((e) => e.toJson()).toList(),
      if (instance.needs case final value?) 'needs': value,
    };
