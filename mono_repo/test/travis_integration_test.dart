import 'dart:io';

@TestOn('!windows')
import 'package:mono_repo/src/package_config.dart';
import 'package:path/path.dart' as p;
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
'''),
      d.file('some_dart_file.dart', 'void main() => print("hello");'),
    ]).create();

    testGenerateTravisConfig(
      printMatcher: stringContainsInOrder([
        'package:pkg_a',
        'package:pkg_b',
        'Make sure to mark `tool/travis.sh` as executable.'
      ]),
    );

    //print(File(p.join(d.sandbox, travisFileName)).readAsStringSync());

    final proc = await TestProcess.start(
      '/bin/bash',
      [
        'tool/travis.sh',
        'dartanalyzer',
        'command',
      ],
      environment: {
        'PKGS': 'pkg_a pkg_b pkg_c',
      },
      workingDirectory: d.sandbox,
    );

    final output = await proc.stdoutStream().join('\n');

    await proc.shouldExit(0);
    printOnFailure("r'''\n$output'''");

    expect(output, r'''
PKG: pkg_a
Resolving dependencies...
No dependencies changed.

PKG: pkg_a; TASK: dartanalyzer
dartanalyzer .
Analyzing pkg_a...
PKG: pkg_a; TASK: dartanalyzer - FAILED

PKG: pkg_a; TASK: command
echo "testing 1 2 3"
testing 1 2 3
PKG: pkg_a; TASK: command - SUCCEEDED

PKG: pkg_b
Resolving dependencies...
PKG: pkg_b; 'pub upgrade' - FAILED

PKG: pkg_c
Resolving dependencies...
No dependencies changed.

PKG: pkg_c; TASK: dartanalyzer
dartanalyzer .
Analyzing pkg_c...
No issues found!
PKG: pkg_c; TASK: dartanalyzer - SUCCEEDED

PKG: pkg_c; TASK: command
echo "testing 1 2 3"
testing 1 2 3
PKG: pkg_c; TASK: command - SUCCEEDED
''');
  });
}

const _monoPkgContent = r'''
dart:
 - stable

stages:
  - dartanalyze:
    - dartanalyzer
  - dartfmt:
    - command: echo "testing 1 2 3"
''';
