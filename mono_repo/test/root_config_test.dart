import 'dart:io';

import 'package:mono_repo/src/commands/github/github_yaml.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('RootConfig', () {
    test('parseActionVersions', () {
      final file = File(path.join('..', defaultGitHubWorkflowFilePath));
      final parsedVersions = RootConfig.parseActionVersions(file);

      expect(parsedVersions, isNotEmpty);

      final keys = parsedVersions.keys.toList();
      expect(keys, contains('actions/checkout'));
      expect(keys, contains('dart-lang/setup-dart'));
    });
  });
}
