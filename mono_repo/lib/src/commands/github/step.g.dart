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
      withContent: $checkedConvert('with', (v) => v as Map?),
      name: $checkedConvert('name', (v) => v as String?),
      uses: $checkedConvert('uses', (v) => v as String?),
      run: $checkedConvert('run', (v) => v as String?),
      ifContent: $checkedConvert('if', (v) => v as String?),
      workingDirectory: $checkedConvert(
        'working-directory',
        (v) => v as String?,
      ),
      env: $checkedConvert('env', (v) => v as Map?),
    );
    return val;
  },
  fieldKeyMap: const {
    'withContent': 'with',
    'ifContent': 'if',
    'workingDirectory': 'working-directory',
  },
);

Map<String, dynamic> _$StepToJson(Step instance) => <String, dynamic>{
  'id': ?instance.id,
  'name': ?instance.name,
  'run': ?instance.run,
  'if': ?instance.ifContent,
  'working-directory': ?instance.workingDirectory,
  'env': ?instance.env,
  'uses': ?instance.uses,
  'with': ?instance.withContent,
};
