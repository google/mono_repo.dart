// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: prefer_expression_function_bodies

part of 'github_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitHubConfig _$GitHubConfigFromJson(Map json) {
  return $checkedNew('GitHubConfig', json, () {
    $checkKeys(json, allowedKeys: const ['on', 'cron']);
    final val = GitHubConfig(
      $checkedConvert(
          json,
          'on',
          (v) => (v as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )),
      $checkedConvert(json, 'cron', (v) => v as String),
    );
    return val;
  });
}
