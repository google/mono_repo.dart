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
          allowedKeys: const ['os', 'sdk', 'stages', 'cache'],
        );
        final val = RawConfig(
          oses: $checkedConvert(
              'os',
              (v) =>
                  (v as List<dynamic>?)?.map((e) => e as String).toList() ??
                  ['linux']),
          sdks: $checkedConvert('sdk',
              (v) => (v as List<dynamic>?)?.map((e) => e as String).toList()),
          stages: $checkedConvert(
              'stages',
              (v) => (v as List<dynamic>?)
                  ?.map((e) => RawStage.fromJson(e as Map))
                  .toList()),
          cache: $checkedConvert(
              'cache', (v) => v == null ? null : RawCache.fromJson(v as Map)),
        );
        return val;
      },
      fieldKeyMap: const {'oses': 'os', 'sdks': 'sdk'},
    );

RawCache _$RawCacheFromJson(Map json) => $checkedCreate(
      'RawCache',
      json,
      ($checkedConvert) {
        final val = RawCache(
          $checkedConvert('directories',
              (v) => (v as List<dynamic>).map((e) => e as String).toList()),
        );
        return val;
      },
    );
