// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: require_trailing_commas

part of 'raw_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RawConfig _$RawConfigFromJson(Map json) => $checkedCreate(
  'RawConfig',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'os',
        'sdk',
        'stages',
        'cache',
        'pre_steps',
        'post_steps',
      ],
    );
    final val = RawConfig(
      oses: $checkedConvert(
        'os',
        (v) =>
            (v as List<dynamic>?)?.map((e) => e as String).toList() ??
            ['linux'],
      ),
      sdks: $checkedConvert(
        'sdk',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
      ),
      stages: $checkedConvert(
        'stages',
        (v) => (v as List<dynamic>?)
            ?.map((e) => RawStage.fromJson(e as Map))
            .toList(),
      ),
      cache: $checkedConvert(
        'cache',
        (v) => v == null ? null : RawCache.fromJson(v as Map),
      ),
      preSteps: $checkedConvert(
        'pre_steps',
        (v) => (v as List<dynamic>?)?.map((e) => e as Map).toList(),
      ),
      postSteps: $checkedConvert(
        'post_steps',
        (v) => (v as List<dynamic>?)?.map((e) => e as Map).toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'oses': 'os',
    'sdks': 'sdk',
    'preSteps': 'pre_steps',
    'postSteps': 'post_steps',
  },
);

RawCache _$RawCacheFromJson(Map json) =>
    $checkedCreate('RawCache', json, ($checkedConvert) {
      final val = RawCache(
        $checkedConvert(
          'directories',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
      );
      return val;
    });
