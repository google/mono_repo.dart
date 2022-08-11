// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:mono_repo/src/commands/ci_script/generate.dart';
import 'package:mono_repo/src/commands/github/generate.dart';
import 'package:mono_repo/src/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

// TODO(kevmoo): validate `mono_repo --help` output, too!

void main() {
  test('validate readme content', () {
    final readmeContent = File('README.md')
        .readAsStringSync()
        // For Windows tests
        .replaceAll('\r', '');
    expect(readmeContent, contains(_yamlWrap(_pkgYaml)));
    expect(readmeContent, contains(_yamlWrap(_repoYaml)));
  });

  test(
    'validate readme example output',
    () async {
      await d.file('mono_repo.yaml', _repoYaml).create();
      await d.dir('sub_pkg', [
        d.file(monoPkgFileName, _pkgYaml),
        d.file('pubspec.yaml', '''
name: sub_pkg
environment:
  sdk: '>=2.17.0 <3.0.0'
''')
      ]).create();

      testGenerateConfig(
        printMatcher: stringContainsInOrder(
          [
            'package:sub_pkg\n',
            'Make sure to mark `tool/ci.sh` as executable.\n',
            '  chmod +x tool/ci.sh\n',
          ],
        ),
      );

      void validateFile(
        String fileToVerify,
        String expectedOutputFileName,
      ) {
        final inputFile = File(p.join(d.sandbox, fileToVerify));
        final sourceContent = inputFile.readAsStringSync();
        validateOutput(
          'readme_$expectedOutputFileName.txt',
          sourceContent,
        );
      }

      validateFile(ciScriptPath, 'ci');
      validateFile(githubWorkflowFilePath('lint'), 'github_lints');
      validateFile(defaultGitHubWorkflowFilePath, 'github_defaults');
    },
    onPlatform: const {'windows': Skip('Many platform-specific differences')},
  );
}

String _yamlWrap(String content) => '```yaml\n$content```';

const _repoYaml = r'''
# Enabled GitHub actions - https://docs.github.com/actions
# If you have no configuration, you can set the value to `true` or just leave it
# empty.
github:
  # Specify the `on` key to configure triggering events.
  # See https://docs.github.com/actions/reference/workflow-syntax-for-github-actions#on
  # The default values is
  # on:
  #   push:
  #     branches:
  #       - main
  #       - master
  #   pull_request:

  # Setting just `cron` is a shortcut to keep the defaults for `push` and
  # `pull_request` while adding a single `schedule` entry.
  # `on` and `cron` cannot both be set.
  cron: '0 0 * * 0' # “At 00:00 (UTC) on Sunday.”
  
  # Specify additional environment variables accessible to all jobs
  env:
    FOO: BAR

  # You can group stages into individual workflows  
  #
  # Any stages that are omitted here are put in a default workflow
  # named `dart.yml`.
  workflows:
    # The key here is the name of the file - .github/workflows/lint.yml
    lint:
      # This populates `name` in the workflow
      name: Dart Lint CI
      # These are the stages that are populated in the workflow file
      stages:
      - analyze

  # You can add custom github actions configurations to run after completion
  # of all other jobs here. This accepts normal github job config except that
  # the `needs` config is filled in for you, and you aren't allowed to pass it.
  on_completion:
    # Example job that pings a web hook url stored in a github secret with a
    # json payload linking to the failed run.
    - name: "Notify failure"
      runs-on: ubuntu-latest
      # By default this job will only run if all dependent jobs are successful,
      # but we want to run in the failure case for this purpose.
      if: failure()
      steps:
        - run: >
            curl -H "Content-Type: application/json" -X POST -d \
              "{'text':'Build failed! ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}'}" \
              "${CHAT_WEBHOOK_URL}"
          env:
            CHAT_WEBHOOK_URL: ${{ secrets.CHAT_WEBHOOK_URL }}

  # You can customize stage ordering as well as make certain stages be
  # conditional here, this is supported for all CI providers. The `if`
  # condition should use the appropriate syntax for the provider it is being
  # configured for.
  stages:
    - name: cron
      # Only run this stage for scheduled cron jobs
      if: github.event_name == 'schedule'

# Adds a job that runs `mono_repo generate --validate` to check that everything
# is up to date. You can specify the value as just `true` or give a `stage`
# you'd like this job to run in.
self_validate: analyze

# Use this key to merge stages across packages to create fewer jobs
merge_stages:
- analyze

# When using `test_with_coverage`, this setting configures the service that
# results are uploaded to.
# Note: you can configure both options, but this would be unusual.
# Note: you can configure this key with no values, to just generate the files
#   locally. This may be to enable other, custom processing.
coverage_service:
# https://coveralls.io/ - the default
- coveralls
# https://codecov.io/ – the other option
- codecov
''';

const _pkgYaml = r'''
# Every entry must be associated with at least one SDK version – corresponding
# to the Dart SDK version or the Flutter framework version, depending on the
# type of package. It can be specified at the top-lever as a single value or
# an array. Alternatively, you can specify the SDK version(s) within each job.
sdk:
 - dev
 # Specific `pubspec` to test the lower-bound SDK defined in pubspec.yaml
 # This is only supported for Dart packages (not Flutter).
 - pubspec

stages:
  # Register two jobs to run under the `analyze` stage.
  - analyze:
    - analyze
    - format
  - unit_test:
    - test
  # Example cron stage which will only run for scheduled jobs (here we run
  # multiple OS configs for extra validation as an example).
  #
  # See the `mono_repo.yaml` example above for where this stage is specially
  # configured.
  - cron:
    - test:
      os:
        - linux
        - windows
''';
