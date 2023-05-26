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
          ifContent: $checkedConvert('if', (v) => v as String?),
          needs: $checkedConvert('needs',
              (v) => (v as List<dynamic>?)?.map((e) => e as String).toList()),
          outputs: $checkedConvert(
              'outputs',
              (v) => (v as Map?)?.map(
                    (k, e) => MapEntry(k as String, e as String),
                  )),
          permissions: $checkedConvert(
              'permissions',
              (v) => (v as Map?)?.map(
                    (k, e) => MapEntry(k as String, e as String),
                  )),
        );
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
  writeNotNull('outputs', instance.outputs);
  writeNotNull('permissions', instance.permissions);
  return val;
}
