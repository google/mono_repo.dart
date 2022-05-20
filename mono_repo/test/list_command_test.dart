import 'package:mono_repo/src/commands/list_command.dart';
import 'package:mono_repo/src/root_config.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

void main() {
  setUp(listReadmeSetup);
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
