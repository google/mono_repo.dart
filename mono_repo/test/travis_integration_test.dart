@TestOn('!windows')

import 'package:mono_repo/src/package_config.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import 'shared.dart';

void main() {
  glyph.ascii = false;

  test('integration', () async {
    await d.file('mono_repo.yaml', 'pretty_ansi: false').create();
    await d.dir('pkg_a', [
      d.file(
        monoPkgFileName,
        _monoPkgContent,
      ),
      d.file('pubspec.yaml', '''
name: pkg_a
      ''')
    ]).create();

    await d.dir('pkg_b', [
      d.file(
        monoPkgFileName,
        _monoPkgContent,
      ),
      d.file('pubspec.yaml', '''
name: pkg_b

dependencies:
  not_a_package_at_all: any
      ''')
    ]).create();

    await d.dir('pkg_c', [
      d.file(
        monoPkgFileName,
        _monoPkgContent,
      ),
      d.file('pubspec.yaml', '''
name: pkg_c
''')
    ]).create();

    testGenerateTravisConfig(
      printMatcher: stringContainsInOrder([
        'package:pkg_a',
        'package:pkg_b',
        'Make sure to mark `tool/travis.sh` as executable.'
      ]),
    );

    //print(File(p.join(d.sandbox, travisShPath)).readAsStringSync());

    final proc = await TestProcess.start(
      '/bin/bash',
      [
        'tool/travis.sh',
        'dartanalyzer',
      ],
      environment: {
        'PKGS': 'pkg_a pkg_b pkg_c',
      },
      workingDirectory: d.sandbox,
    );

    final output = await proc.stdoutStream().join('\n');
    expect(output, r'''
PKG: pkg_a
Resolving dependencies...
No dependencies changed.

PKG: pkg_a; TASK: dartanalyzer
dartanalyzer .
Analyzing pkg_a...

PKG: pkg_b
Resolving dependencies...
pub upgrade failed

PKG: pkg_c
Resolving dependencies...
No dependencies changed.

PKG: pkg_c; TASK: dartanalyzer
dartanalyzer .
Analyzing pkg_c...
''');

    await proc.shouldExit(3);
  });
}

const _monoPkgContent = r'''
dart:
 - stable

stages:
  - some_things:
    - dartanalyzer:
''';
