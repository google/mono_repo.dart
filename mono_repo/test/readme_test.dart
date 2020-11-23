// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:mono_repo/src/commands/ci_script/generate.dart';
import 'package:mono_repo/src/commands/github/generate.dart';
import 'package:mono_repo/src/commands/travis/generate.dart';
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

  test('validate readme example output', () async {
    await d.file('mono_repo.yaml', _repoYaml).create();
    await d.dir('sub_pkg', [
      d.file(monoPkgFileName, _pkgYaml),
      d.file('pubspec.yaml', '''
name: sub_pkg
''')
    ]).create();

    testGenerateConfig(
      forceTravis: false,
      forceGitHub: false,
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

    validateFile(travisFileName, 'travis');
    validateFile(ciScriptPath, 'ci');
    validateFile(githubWorkflowFilePath('lint'), 'github_lints');
    validateFile(defaultGitHubWorkflowFilePath, 'github_defaults');
  }, onPlatform: const {'windows': Skip('Many platform-specific differences')});
}

String _yamlWrap(String content) => '```yaml\n$content```';

const _repoYaml = r'''
# Adds a job that runs `mono_repo generate --validate` to check that everything
# is up to date.
# You can specify the value as just `true` or give a `stage` you'd like this
# job to run in.
self_validate: analyze

# This would enable both CI configurations, you probably only want one though.
travis:
github:
  # Setting just `cron` keeps the defaults for `push` and `pull_request`
  cron: '0 0 * * 0' # “At 00:00 (UTC) on Sunday.”

  # You can group stages into individual workflows  
  workflows:
    # The key here is the name of the file - .github/workflows/lint.yml
    lint:
      # This populates `name` in the workflow
      name: Dart Lint CI
      # These are the stages that are populated in the workflow file
      stages:
      - analyze
  # Any stages that are omitted here are put in a default workflow 
  # named `dart.yml`.
''';

const _pkgYaml = r'''
# This key is required. It specifies the Dart SDKs your tests will run under
# You can provide one or more value.
# See https://docs.travis-ci.com/user/languages/dart#choosing-dart-versions-to-test-against
# for valid values
dart:
 - dev

stages:
  # Register two jobs to run under the `analyze` stage.
  - analyze:
    - dartanalyzer
    - dartfmt
  - unit_test:
    - test
''';
