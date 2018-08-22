// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'raw_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RawConfig _$RawConfigFromJson(Map json) {
  return $checkedNew('RawConfig', json, () {
    $checkKeys(json, allowedKeys: ['dart', 'stages', 'cache']);
    var val = RawConfig(
        $checkedConvert(json, 'dart',
            (v) => (v as List)?.map((e) => e as String)?.toList()),
        $checkedConvert(
            json,
            'stages',
            (v) => (v as List)
                ?.map((e) => e == null ? null : RawStage.fromJson(e as Map))
                ?.toList()),
        $checkedConvert(json, 'cache',
            (v) => v == null ? null : RawCache.fromJson(v as Map)));
    return val;
  }, fieldKeyMap: {'sdks': 'dart'});
}

RawCache _$RawCacheFromJson(Map json) {
  return $checkedNew('RawCache', json, () {
    var val = RawCache($checkedConvert(json, 'directories',
        (v) => (v as List)?.map((e) => e as String)?.toList()));
    return val;
  });
}
