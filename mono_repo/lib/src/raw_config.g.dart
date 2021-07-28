// GENERATED CODE - DO NOT MODIFY BY HAND

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
          allowedKeys: const ['os', 'dart', 'stages', 'cache'],
        );
        final val = RawConfig(
          $checkedConvert(
              'os',
              (v) =>
                  (v as List<dynamic>?)?.map((e) => e as String).toList() ??
                  ['linux']),
          $checkedConvert('dart',
              (v) => (v as List<dynamic>?)?.map((e) => e as String).toList()),
          $checkedConvert(
              'stages',
              (v) => (v as List<dynamic>?)
                  ?.map((e) => RawStage.fromJson(e as Map))
                  .toList()),
          $checkedConvert(
              'cache', (v) => v == null ? null : RawCache.fromJson(v as Map)),
        );
        return val;
      },
      fieldKeyMap: const {'oses': 'os', 'sdks': 'dart'},
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
