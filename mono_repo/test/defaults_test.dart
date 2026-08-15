import 'package:mono_repo/src/commands/github/github_yaml.dart';
import 'package:mono_repo/src/yaml.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

void main() {
  test('cascading defaults to subpackages without mono_pkg.yaml', () async {
    await d.dir('sub_pkg', [
      d.file('pubspec.yaml', '''
name: pkg_name
environment:
  sdk: '^3.0.0'
      '''),
    ]).create();

    final monoConfigContent = toYaml({
      'defaults': {
        'sdk': ['dev'],
        'stages': [
          {
            'analyze': ['analyze'],
          },
        ],
      },
    });
    await d.file('mono_repo.yaml', monoConfigContent).create();

    testGenerateConfig(
      printMatcher: stringContainsInOrder(['package:sub_pkg', 'Wrote ']),
    );

    await d
        .file(defaultGitHubWorkflowFilePath, contains('sdk: "dev"'))
        .validate();
  });

  test('subpackage overrides defaults', () async {
    await d.dir('sub_pkg', [
      d.file('mono_pkg.yaml', '''
sdk:
  - stable
'''),
      d.file('pubspec.yaml', '''
name: pkg_name
environment:
  sdk: '^3.0.0'
      '''),
    ]).create();

    final monoConfigContent = toYaml({
      'defaults': {
        'sdk': ['dev'],
        'stages': [
          {
            'analyze': ['analyze'],
          },
        ],
      },
    });
    await d.file('mono_repo.yaml', monoConfigContent).create();

    testGenerateConfig(
      printMatcher: stringContainsInOrder(['package:sub_pkg', 'Wrote ']),
    );

    // Should use stable SDK from mono_pkg.yaml, inheriting stages from defaults
    await d
        .file(defaultGitHubWorkflowFilePath, contains('sdk: "stable"'))
        .validate();
    await d
        .file(defaultGitHubWorkflowFilePath, isNot(contains('sdk: "dev"')))
        .validate();
    await d
        .file(defaultGitHubWorkflowFilePath, contains('name: "analyze; '))
        .validate();
  });
}
