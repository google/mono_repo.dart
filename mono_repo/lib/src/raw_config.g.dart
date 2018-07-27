// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'raw_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RawConfig _$RawConfigFromJson(Map json) {
  return $checkedNew('RawConfig', json, () {
    $checkKeys(json, allowedKeys: const ['dart', 'stages', 'cache']);
    var val = new RawConfig(
        $checkedConvert(json, 'dart',
            (v) => (v as List)?.map((e) => e as String)?.toList()),
        $checkedConvert(
            json,
            'stages',
            (v) => (v as List)
                ?.map((e) => e == null ? null : new RawStage.fromJson(e as Map))
                ?.toList()),
        $checkedConvert(json, 'cache',
            (v) => v == null ? null : new RawCache.fromJson(v as Map)));
    return val;
  }, fieldKeyMap: const {'sdks': 'dart'});
}

RawCache _$RawCacheFromJson(Map json) {
  return $checkedNew('RawCache', json, () {
    var val = new RawCache($checkedConvert(json, 'directories',
        (v) => (v as List)?.map((e) => e as String)?.toList()));
    return val;
  });
}
