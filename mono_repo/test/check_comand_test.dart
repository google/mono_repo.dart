import 'package:test/test.dart';

import 'package:mono_repo/src/commands/check.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

main() {
  setUp(sharedSetup);

  test('check', () async {
    var reports = await getPackageReports(rootDirectory: d.sandbox);

    expect(reports, hasLength(4));

    var fooReport = reports['foo'];
    expect(fooReport.packageName, 'foo');
    expect(fooReport.published, isFalse);

    var fooDeps = fooReport.pubspec.dependencies;
    expect(fooDeps, hasLength(2));
    expect(
        (fooDeps['build'] as HostedDependency).version, VersionConstraint.any);
    expect((fooDeps['implied_any'] as HostedDependency).version,
        VersionConstraint.any);

    var barReport = reports['bar'];
    expect(barReport.packageName, 'bar');
    expect(barReport.published, isFalse);

    expect(barReport.pubspec.dependencies, hasLength(1));

    var gitDep = barReport.pubspec.dependencies['build'] as GitDependency;
    expect(gitDep.url, Uri.parse('https://github.com/dart-lang/build.git'));
    expect(gitDep.path, 'build');
    expect(gitDep.ref, 'hacking');

    var bazReport = reports['baz'];
    expect(bazReport.packageName, 'baz');
    expect(bazReport.published, isFalse);

    expect(bazReport.pubspec.dependencies, hasLength(1));
    expect(bazReport.pubspec.dependencyOverrides, hasLength(1));

    gitDep = bazReport.pubspec.dependencies['build'] as GitDependency;
    expect(gitDep.url, Uri.parse('https://github.com/dart-lang/build.git'));
    expect(gitDep.path, isNull);
    expect(gitDep.ref, isNull);

    var flutterReport = reports['flutter'];
    expect(flutterReport.packageName, 'flutter');
    expect(flutterReport.published, isFalse);
    expect(flutterReport.pubspec.dependencies, hasLength(2));
    expect(flutterReport.pubspec.devDependencies, hasLength(1));

    var sdkDep = flutterReport.pubspec.dependencies['flutter'] as SdkDependency;
    expect(sdkDep.sdk, 'flutter');
  });

  test('check recursive', () async {
    var reports =
        await getPackageReports(rootDirectory: d.sandbox, recursive: true);

    expect(reports, hasLength(5));

    var recursiveReport = reports['baz/recursive'];
    expect(recursiveReport.packageName, 'baz.recursive');
    expect(recursiveReport.published, isFalse);
    expect(recursiveReport.pubspec.dependencies, hasLength(1));
  });
}
