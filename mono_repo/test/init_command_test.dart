import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:mono_repo/src/commands/init.dart';

void main() {
  const repoCfgFileName = 'mono_repo.yaml';
  const pkgCfgFileName = 'mono_pkg.yaml';

  test('scaffold a new mono repo', () async {
    await d.dir('top_level', [
      d.dir('package1', [d.file('pubspec.yaml')]),
      d.dir('package2', [d.file('pubspec.yaml')])
    ]).create();
    final rootDirectory = '${d.sandbox}/top_level';
    final package1Directory = '${d.sandbox}/top_level/package1';
    final package2Directory = '${d.sandbox}/top_level/package2';

    final repoCfg = p.join(rootDirectory, repoCfgFileName);
    final pkg1Cfg = p.join(package1Directory, pkgCfgFileName);
    final pkg2Cfg = p.join(package2Directory, pkgCfgFileName);
    scaffold(rootDirectory, false);
    expect(
        File(repoCfg).existsSync() &&
            File(pkg1Cfg).existsSync() &&
            File(pkg2Cfg).existsSync(),
        equals(true));
  });
}
