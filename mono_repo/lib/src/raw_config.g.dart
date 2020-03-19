// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: prefer_expression_function_bodies

part of 'raw_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RawConfig _$RawConfigFromJson(Map json) {
  return $checkedNew('RawConfig', json, () {
    $checkKeys(json, allowedKeys: const ['os', 'dart', 'stages', 'cache']);
    final val = RawConfig(
      $checkedConvert(json, 'os',
              (v) => (v as List)?.map((e) => e as String)?.toList()) ??
          ['linux'],
      $checkedConvert(
          json, 'dart', (v) => (v as List)?.map((e) => e as String)?.toList()),
      $checkedConvert(
          json,
          'stages',
          (v) => (v as List)
              ?.map((e) => e == null ? null : RawStage.fromJson(e as Map))
              ?.toList()),
      $checkedConvert(
          json, 'cache', (v) => v == null ? null : RawCache.fromJson(v as Map)),
    );
    return val;
  }, fieldKeyMap: const {'oses': 'os', 'sdks': 'dart'});
}

RawCache _$RawCacheFromJson(Map json) {
  return $checkedNew('RawCache', json, () {
    final val = RawCache(
      $checkedConvert(json, 'directories',
          (v) => (v as List)?.map((e) => e as String)?.toList()),
    );
    return val;
  });
}
