import 'dart:io';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:mono_repo/src/commands/init.dart';

void main() {
  const commentText =
      '# See with https://github.com/dart-lang/mono_repo for details on this file\n';
  test('scaffold a new mono repo', () async {
    await d.dir(
        'top_level', [d.dir('package1', []), d.dir('package2', [])]).create();
    String rootDirectory = '${d.sandbox}/top_level';
    scaffold(rootDirectory, false);
    await d.dir('top_level', [
      d.file('mono_repo.yaml', commentText),
      d.dir('package1', [
        d.file('pubspec.yaml', 'name: package1\n'),
        d.file('mono_pkg.yaml', commentText)
      ]),
      d.dir('package2', [
        d.file('pubspec.yaml', 'name: package2\n'),
        d.file('mono_pkg.yaml', commentText)
      ])
    ]).validate();
  });
}
