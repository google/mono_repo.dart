@TestOn('!windows')
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:mono_repo/src/commands/travis.dart';
import 'package:mono_repo/src/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import 'shared.dart';

void main() {
  glyph.ascii = false;

  setUpAll(() async {
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
      printMatcher: '''
package:pkg_a
package:pkg_b
package:pkg_c
Wrote `${p.join(d.sandbox, travisFileName)}`.
$travisShPathMessage''',
    );
  });

  _registerTest(
    'all packages with task failures',
    args: [
      'dartanalyzer',
      'command_0',
    ],
    pkgsEnvironment: 'pkg_a pkg_b pkg_c',
    expectedExitCode: 1,
  );

  _registerTest(
    'just successes',
    args: [
      'dartanalyzer',
      'command_0',
    ],
    pkgsEnvironment: 'pkg_c',
    expectedExitCode: 0,
  );

  _registerTest(
    'no tasks provided',
    args: [],
    pkgsEnvironment: 'pkg_a pkg_b pkg_c',
    expectedExitCode: 64,
  );

  _registerTest(
    'wrong task provided',
    args: [
      'not_a_task',
    ],
    pkgsEnvironment: 'pkg_c',
    expectedExitCode: 64,
  );

  _registerTest(
    'bad PKGS provided',
    args: [
      'dartanalyzer',
      'command_0',
    ],
    pkgsEnvironment: 'pkg_d',
    expectedExitCode: 64,
  );

  _registerTest(
    'no PKGS set',
    args: [
      'dartanalyzer',
      'command_0',
    ],
    pkgsEnvironment: '',
    expectedExitCode: 64,
  );

  _registerTest(
    'test messing with current directory',
    args: [
      'command_1',
    ],
    pkgsEnvironment: 'pkg_c',
    expectedExitCode: 70,
  );
}

void _registerTest(
  String name, {
  @required List<String> args,
  @required String pkgsEnvironment,
  @required int expectedExitCode,
}) {
  test(name, () async {
    // Make sure we're executing from the right directory!
    await d
        .file('test/travis_integration_test.dart', isNotEmpty)
        .validate(p.current);

    final proc = await TestProcess.start(
      '/bin/bash',
      [
        'tool/travis.sh',
        ...args,
      ],
      environment: {
        'PKGS': pkgsEnvironment,
      },
      workingDirectory: d.sandbox,
    );

    final output = await proc.stdoutStream().join('\n');

    await proc.shouldExit(expectedExitCode);
    printOnFailure("r'''\n$output''',");

    final fileName = [name.toLowerCase().replaceAll(' ', '_'), '.txt'].join();

    final outputFile = File(p.join(
      'test',
      'travis_integration_outputs',
      fileName,
    ));

    if (outputFile.existsSync()) {
      expect(output, outputFile.readAsStringSync());
    } else {
      outputFile
        ..createSync(recursive: true)
        ..writeAsStringSync(
          output,
          mode: FileMode.writeOnly,
          flush: true,
        );
      fail('${outputFile.path} does not exist. Writing output.');
    }
  });
}

const _monoPkgContent = r'''
dart:
 - stable

stages:
  - stage1:
    - dartanalyzer
  - stage2:
    - command: echo "testing 1 2 3"
  - stage3:
    - command: popd >/dev/null  
''';
