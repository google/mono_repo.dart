import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

import 'repo_package.dart';

class InitCommand extends Command {
  @override
  String get name => 'init';

  @override
  String get description => 'Initialize a new repository.';

  @override
  Future run() => init();
}

Future init() async {
  // TODO: check to see if we're in the root of a GIT repo. If not, warn.

  var packagesPath = p.join(p.current, 'packages.yaml');

  if (FileSystemEntity.typeSync(packagesPath) !=
      FileSystemEntityType.NOT_FOUND) {
    print("`$packagesPath` already exists.");
    return;
  }

  var pubspecPath = p.join(p.current, 'pubspec.yaml');
  if (FileSystemEntity.typeSync(pubspecPath) !=
      FileSystemEntityType.NOT_FOUND) {
    print('Found `pubspec.yaml` in the current directory. Not supported.');
    return;
  }

  var packages = <String, RepoPackage>{};

  for (Directory subdir
      in Directory.current.listSync().where((fse) => fse is Directory)) {
    File pubspecFile = subdir.listSync().firstWhere(
        (fse) => fse is File && p.basename(fse.path) == 'pubspec.yaml',
        orElse: () => null);

    if (pubspecFile != null) {
      var pubspecContent = y.loadYaml(pubspecFile.readAsStringSync()) as Map;

      var name = pubspecContent['name'] as String;
      if (name == null) {
        throw new StateError(
            "No name for the pubspec at `${pubspecFile.path}`.");
      }

      var publishedGuess = pubspecContent.containsKey('version');

      packages[p.relative(subdir.path)] = new RepoPackage(name, publishedGuess);
    }
  }

  var file = new File(packagesPath);
  var writer = new StringBuffer();
  writer.writeln('# Created by multi_repo');

  packages.forEach((k, v) {
    writer.writeln("$k:");
    writer.writeln("  name: '${v.name}'");
    writer.writeln("  published: ${v.published}");
  });

  file.writeAsStringSync(writer.toString(), mode: FileMode.WRITE_ONLY);
}
