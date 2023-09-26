import 'dart:async';
import 'dart:io';

import 'package:mono_repo/src/commands/dart.dart';
import 'package:mono_repo/src/commands/pub.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('valid setup', () {
    setUp(_setup);

    test('can run pub get', () async {
      expect(
        () => dart(
          RootConfig(rootDirectory: d.sandbox),
          ['pub', 'get'],
          PubCommand().executableForPackage,
        ),
        prints(allOf(contains('success!'), isNot(contains('Failures:')))),
      );
    });

    test('can run dart fix', () async {
      final file = File(p.join(d.sandbox, 'foo', 'fix.dart'))
        ..writeAsStringSync('''
import 'b.dart';
import 'a.dart';
''');
      addTearDown(() => file.deleteSync);
      await expectLater(
        () => dart(
          RootConfig(rootDirectory: d.sandbox),
          ['fix', '--apply'],
          (_) => Executable.dart,
        ),
        prints(allOf(contains('success!'), isNot(contains('Failures:')))),
      );
      expect(file.readAsStringSync(), '''
import 'a.dart';
import 'b.dart';
''');
    });
  });
}

Future _setup() async {
  await d.dir('foo', [
    d.file('mono_pkg.yaml', ''),
    d.file('pubspec.yaml', r'''
name: dart_app
environment:
  sdk: ^3.0.0

dependencies:
  meta: any
'''),
    d.file('analysis_options.yaml', '''
linter:
  rules:
    - directives_ordering
'''),
  ]).create();
}
