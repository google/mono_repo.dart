// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: require_trailing_commas

part of 'github_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitHubConfig _$GitHubConfigFromJson(Map json) => $checkedCreate(
      'GitHubConfig',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'env',
            'on',
            'on_completion',
            'cron',
            'stages',
            'workflows'
          ],
        );
        final val = GitHubConfig(
          $checkedConvert(
              'env',
              (v) => (v as Map?)?.map(
                    (k, e) => MapEntry(k as String, e),
                  )),
          $checkedConvert(
              'on',
              (v) => (v as Map?)?.map(
                    (k, e) => MapEntry(k as String, e),
                  )),
          $checkedConvert(
              'on_completion',
              (v) => (v as List<dynamic>?)
                  ?.map(
                      (e) => Job.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList()),
          $checkedConvert('cron', (v) => v as String?),
          $checkedConvert('stages', (v) => v as List<dynamic>?),
          $checkedConvert(
              'workflows',
              (v) => (v as Map?)?.map(
                    (k, e) => MapEntry(
                        k as String, GitHubWorkflow.fromJson(e as Map)),
                  )),
        );
        return val;
      },
      fieldKeyMap: const {'onCompletion': 'on_completion'},
    );

GitHubWorkflow _$GitHubWorkflowFromJson(Map json) => $checkedCreate(
      'GitHubWorkflow',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const ['name', 'stages'],
          requiredKeys: const ['name', 'stages'],
          disallowNullValues: const ['name', 'stages'],
        );
        final val = GitHubWorkflow(
          $checkedConvert('name', (v) => v as String),
          $checkedConvert('stages',
              (v) => (v as List<dynamic>).map((e) => e as String).toSet()),
        );
        return val;
      },
    );
