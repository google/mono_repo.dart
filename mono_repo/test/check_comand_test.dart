import 'dart:async';

import 'package:mono_repo/src/commands/check.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

void main() {
  test('error with mono_pkg file, but no pubspec', () async {
    await d.dir('subdir', [d.file('mono_pkg.yaml')]).create();

    expect(
        () => getPackageReports(RootConfig(rootDirectory: d.sandbox)),
        throwsUserExceptionWith(
            'A `mono_pkg.yaml` file was found, but missing '
            'an expected `pubspec.yaml` in `subdir`.',
            isNull));
  });

  group('valid setup', () {
    setUp(_setup);

    test('check', () {
      final reports = getPackageReports(RootConfig(rootDirectory: d.sandbox));

      expect(reports.keys,
          ['bar', 'baz', p.join('baz', 'recursive'), 'flutter', 'foo']);

      final fooReport = reports['foo'];
      expect(fooReport.packageName, 'foo');
      expect(fooReport.published, isFalse);

      final fooDeps = fooReport.pubspec.dependencies;
      expect(fooDeps, hasLength(2));
      expect((fooDeps['build'] as HostedDependency).version,
          VersionConstraint.any);
      expect((fooDeps['implied_any'] as HostedDependency).version,
          VersionConstraint.any);

      final barReport = reports['bar'];
      expect(barReport.packageName, 'bar');
      expect(barReport.published, isFalse);

      expect(barReport.pubspec.dependencies, hasLength(1));

      var gitDep = barReport.pubspec.dependencies['build'] as GitDependency;
      expect(gitDep.url, Uri.parse('https://github.com/dart-lang/build.git'));
      expect(gitDep.path, 'build');
      expect(gitDep.ref, 'hacking');

      final bazReport = reports['baz'];
      expect(bazReport.packageName, 'baz');
      expect(bazReport.published, isFalse);

      expect(bazReport.pubspec.dependencies, hasLength(1));
      expect(bazReport.pubspec.dependencyOverrides, hasLength(1));

      gitDep = bazReport.pubspec.dependencies['build'] as GitDependency;
      expect(gitDep.url, Uri.parse('https://github.com/dart-lang/build.git'));
      expect(gitDep.path, isNull);
      expect(gitDep.ref, isNull);

      final flutterReport = reports['flutter'];
      expect(flutterReport.packageName, 'flutter');
      expect(flutterReport.published, isFalse);
      expect(flutterReport.pubspec.dependencies, hasLength(2));
      expect(flutterReport.pubspec.devDependencies, hasLength(1));

      final sdkDep =
          flutterReport.pubspec.dependencies['flutter'] as SdkDependency;
      expect(sdkDep.sdk, 'flutter');

      final recursiveReport = reports[p.join('baz', 'recursive')];
      expect(recursiveReport.packageName, 'baz.recursive');
      expect(recursiveReport.published, isTrue);
      expect(recursiveReport.pubspec.dependencies, hasLength(1));
    });

    test('check no recursive', () {
      final reports = getPackageReports(
          RootConfig(rootDirectory: d.sandbox, recursive: false));

      expect(reports.keys, ['bar', 'baz', 'flutter', 'foo']);
    });
  });
}

Future _setup() async {
  await d.dir('ignored', [
    d.file('pubspec.yaml', r'''
name: no_mono_repo_file

dependencies:
  build: any
  implied_any:
''')
  ]).create();

  await d.dir('foo', [
    d.file('mono_pkg.yaml', ''),
    d.file('pubspec.yaml', r'''
name: foo

dependencies:
  build: any
  implied_any:
''')
  ]).create();

  await d.dir('bar', [
    d.file('mono_pkg.yaml', ''),
    d.file('pubspec.yaml', r'''
name: bar

dependencies:
  build:
    git:
      url: https://github.com/dart-lang/build.git
      path: build
      ref: hacking
''')
  ]).create();

  await d.dir('baz', [
    d.file('mono_pkg.yaml', ''),
    d.file('pubspec.yaml', r'''
name: baz

dependencies:
  build:
    git: https://github.com/dart-lang/build.git
dependency_overrides:
  analyzer:
'''),
    d.dir('recursive', [
      d.file('mono_pkg.yaml', ''),
      d.file('pubspec.yaml', r'''
name: baz.recursive
version: 1.0.0

dependencies:
  baz: any
        '''),
    ]),
  ]).create();

  await d.dir('flutter', [
    d.file('mono_pkg.yaml', ''),
    // typical pubspec.yaml from flutter
    d.file('pubspec.yaml', r'''
name: flutter
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^0.1.0
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
  assets:
   - images/a_dot_burr.jpeg
  fonts:
    - family: Schyler
      fonts:
        - asset: fonts/Schyler-Regular.ttf
        - asset: fonts/Schyler-Italic.ttf
          style: italic
          weight: 700
''')
  ]).create();
}
