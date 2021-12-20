import 'dart:async';

import 'package:mono_repo/src/commands/pub.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('valid setup', () {
    setUp(_setup);

    test('can run pub get', () async {
      expect(() => pub(RootConfig(rootDirectory: d.sandbox), ['get']),
          prints(allOf(contains('success!'), isNot(contains('Failures:')))));
    });
  });
}

Future _setup() async {
  await d.dir('foo', [
    d.file('mono_pkg.yaml', ''),
    d.file('pubspec.yaml', r'''
name: dart_app
environment:
  sdk: '>=2.12.0 <3.0.0'

dependencies:
  meta: any
''')
  ]).create();
}
