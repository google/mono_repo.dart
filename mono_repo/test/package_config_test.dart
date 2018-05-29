import 'package:test/test.dart';

import 'package:mono_repo/src/commands/check.dart' hide DependencyType;
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

main() {
  setUp(sharedSetup);

  test('empty', () async {
    await d.file('mono_repo.yaml', '# nothing!').create();

    expect(
        () => getPackageReports(rootDirectory: d.sandbox),
        throwsUserExceptionWith(
            'Config file "mono_repo.yaml" contains no values.'));
  });

  test('bad root value', () async {
    await d.file('mono_repo.yaml', '- steve').create();

    expect(
        () => getPackageReports(rootDirectory: d.sandbox),
        throwsUserExceptionWith(
            'Config file "mono_repo.yaml" must contain map values.'));
  });

  test('bad config value', () async {
    await d.file('mono_repo.yaml', 'foo: {published: 42}').create();

    expect(
        () => getPackageReports(rootDirectory: d.sandbox),
        throwsUserExceptionWith('Error parsing "mono_repo.yaml".',
            r'''line 1, column 7: Unsupported value for `published`.
foo: {published: 42}
      ^^^^^^^^^'''));
  });

  test('valid', () async {
    await d.file('mono_repo.yaml', 'foo: {published: false}').create();

    var reports = await getPackageReports(rootDirectory: d.sandbox);

    expect(reports, hasLength(1));
    expect(reports['foo'].published, isFalse);
  });
}
