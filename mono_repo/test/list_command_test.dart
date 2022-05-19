import 'dart:async';

import 'package:mono_repo/src/commands/list_command.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  setUp(_setup);
  test('show everything', () async {
    expect(
      listPackages(
        RootConfig(rootDirectory: d.sandbox),
        onlyPublished: false,
        showItems: {Column.name, Column.path, Column.version, Column.publishTo},
      ),
      [
        'pkg1,pkg1_dir,,',
        'pkg2,pkg2_dir,1.2.3,none',
        'pkg3,pkg3_dir,1.2.3,https://some.random.domain',
        'pkg4,pkg4_dir,1.2.3,',
      ],
    );
  });

  test('only published', () async {
    expect(
      listPackages(
        RootConfig(rootDirectory: d.sandbox),
        onlyPublished: true,
        showItems: {Column.name, Column.path, Column.version, Column.publishTo},
      ),
      [
        'pkg3,pkg3_dir,1.2.3,https://some.random.domain',
        'pkg4,pkg4_dir,1.2.3,',
      ],
    );
  });

  test('path & name', () async {
    expect(
      listPackages(
        RootConfig(rootDirectory: d.sandbox),
        onlyPublished: false,
        showItems: {
          Column.path,
          Column.name,
        },
      ),
      [
        'pkg1_dir,pkg1',
        'pkg2_dir,pkg2',
        'pkg3_dir,pkg3',
        'pkg4_dir,pkg4',
      ],
    );
  });
}

Future _setup() async {
  await d.dir('pkg1_dir', [
    d.file('mono_pkg.yaml', ''),
    d.file('pubspec.yaml', r'''
name: pkg1
environment:
  sdk: '>=2.12.0 <3.0.0'

dependencies:
  meta: any
''')
  ]).create();

  await d.dir('pkg2_dir', [
    d.file('mono_pkg.yaml', ''),
    d.file('pubspec.yaml', r'''
name: pkg2
publish_to: none
version: 1.2.3
environment:
  sdk: '>=2.12.0 <3.0.0'

dependencies:
  meta: any
''')
  ]).create();

  await d.dir('pkg3_dir', [
    d.file('mono_pkg.yaml', ''),
    d.file('pubspec.yaml', r'''
name: pkg3
publish_to: https://some.random.domain
version: 1.2.3
environment:
  sdk: '>=2.12.0 <3.0.0'

dependencies:
  meta: any
''')
  ]).create();

  await d.dir('pkg4_dir', [
    d.file('mono_pkg.yaml', ''),
    d.file('pubspec.yaml', r'''
name: pkg4
version: 1.2.3
environment:
  sdk: '>=2.12.0 <3.0.0'

dependencies:
  meta: any
''')
  ]).create();
}
