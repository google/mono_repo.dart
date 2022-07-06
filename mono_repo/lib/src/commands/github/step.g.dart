// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: require_trailing_commas

part of 'step.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Step _$StepFromJson(Map json) => $checkedCreate(
      'Step',
      json,
      ($checkedConvert) {
        final val = Step._(
          id: $checkedConvert('id', (v) => v as String?),
          withContent: $checkedConvert(
              'with',
              (v) => (v as Map?)?.map(
                    (k, e) => MapEntry(k as String, e),
                  )),
          name: $checkedConvert('name', (v) => v as String?),
          uses: $checkedConvert('uses', (v) => v as String?),
          run: $checkedConvert('run', (v) => v as String?),
          ifContent: $checkedConvert('if', (v) => v as String?),
          workingDirectory:
              $checkedConvert('working-directory', (v) => v as String?),
          env: $checkedConvert(
              'env',
              (v) => (v as Map?)?.map(
                    (k, e) => MapEntry(k as String, e as String),
                  )),
        );
        return val;
      },
      fieldKeyMap: const {
        'withContent': 'with',
        'ifContent': 'if',
        'workingDirectory': 'working-directory'
      },
    );

Map<String, dynamic> _$StepToJson(Step instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('id', instance.id);
  writeNotNull('name', instance.name);
  writeNotNull('run', instance.run);
  writeNotNull('if', instance.ifContent);
  writeNotNull('working-directory', instance.workingDirectory);
  writeNotNull('env', instance.env);
  writeNotNull('uses', instance.uses);
  writeNotNull('with', instance.withContent);
  return val;
}
