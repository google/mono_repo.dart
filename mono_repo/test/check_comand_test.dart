import 'package:test/test.dart';

import 'package:mono_repo/src/commands/check.dart';
import 'package:mono_repo/src/pubspec.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

main() {
  test('check', () async {
    await d.dir('foo', [
      d.file('pubspec.yaml', r'''
name: foo

dependencies:
  build: any
''')
    ]).create();

    await d.dir('bar', [
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
      d.file('pubspec.yaml', r'''
name: baz

dependencies:
  build:
    git: https://github.com/dart-lang/build.git
''')
    ]).create();

    var reports = await getPackageReports(rootDirectory: d.sandbox);

    expect(reports, hasLength(3));

    var fooReport = reports['foo'];
    expect(fooReport.packageName, 'foo');
    expect(fooReport.published, isFalse);

    var barReport = reports['bar'];
    expect(barReport.packageName, 'bar');
    expect(barReport.published, isFalse);

    expect(barReport.pubspec.dependencies, hasLength(1));

    var buildDep = barReport.pubspec.dependencies['build'].data as GitData;
    expect(buildDep.url, Uri.parse('https://github.com/dart-lang/build.git'));
    expect(buildDep.path, 'build');
    expect(buildDep.ref, 'hacking');

    var bazReport = reports['baz'];
    expect(bazReport.packageName, 'baz');
    expect(bazReport.published, isFalse);

    expect(bazReport.pubspec.dependencies, hasLength(1));

    buildDep = bazReport.pubspec.dependencies['build'].data as GitData;
    expect(buildDep.url, Uri.parse('https://github.com/dart-lang/build.git'));
    expect(buildDep.path, isNull);
    expect(buildDep.ref, isNull);
  });
}
