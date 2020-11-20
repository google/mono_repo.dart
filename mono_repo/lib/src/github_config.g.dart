// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: prefer_expression_function_bodies

part of 'github_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitHubConfig _$GitHubConfigFromJson(Map json) {
  return $checkedNew('GitHubConfig', json, () {
    $checkKeys(json, allowedKeys: const ['on', 'cron', 'workflows']);
    final val = GitHubConfig(
      $checkedConvert(
          json,
          'on',
          (v) => (v as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )),
      $checkedConvert(json, 'cron', (v) => v as String),
      $checkedConvert(
          json,
          'workflows',
          (v) => (v as Map)?.map(
                (k, e) => MapEntry(k as String,
                    e == null ? null : GitHubWorkflow.fromJson(e as Map)),
              )),
    );
    return val;
  });
}

GitHubWorkflow _$GitHubWorkflowFromJson(Map json) {
  return $checkedNew('GitHubWorkflow', json, () {
    $checkKeys(json,
        allowedKeys: const ['name', 'stages'],
        requiredKeys: const ['name', 'stages'],
        disallowNullValues: const ['name', 'stages']);
    final val = GitHubWorkflow(
      $checkedConvert(json, 'name', (v) => v as String),
      $checkedConvert(
          json, 'stages', (v) => (v as List).map((e) => e as String).toSet()),
    );
    return val;
  });
}
