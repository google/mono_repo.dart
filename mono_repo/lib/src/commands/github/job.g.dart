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
        final val = Job(
          name: $checkedConvert('name', (v) => v as String?),
          runsOn: $checkedConvert('runs-on', (v) => v as String?),
          steps: $checkedConvert(
              'steps',
              (v) => (v as List<dynamic>)
                  .map(
                      (e) => Step.fromJson(Map<String, dynamic>.from(e as Map)))
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

Map<String, dynamic> _$JobToJson(Job instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('runs-on', instance.runsOn);
  writeNotNull('if', instance.ifContent);
  val['steps'] = instance.steps.map((e) => e.toJson()).toList();
  writeNotNull('needs', instance.needs);
  return val;
}
