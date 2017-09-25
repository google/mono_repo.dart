import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'utils.dart';

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

  if (FileSystemEntity.typeSync(packagesFileName) !=
      FileSystemEntityType.NOT_FOUND) {
    print('`$packagesFileName` already exists.');
    return;
  }

  var pubspecPath = p.join(p.current, 'pubspec.yaml');
  if (FileSystemEntity.typeSync(pubspecPath) !=
      FileSystemEntityType.NOT_FOUND) {
    print('Found `pubspec.yaml` in the current directory. Not supported.');
    return;
  }

  var packages = getPackageConfig();

  var file = new File(packagesFileName);
  var writer = new StringBuffer();
  writer.writeln('# Created by mono_repo');

  packages.forEach((k, v) {
    writer.writeln('$k:');
    writer.writeln('  published: ${v.published}');
  });

  file.writeAsStringSync(writer.toString(), mode: FileMode.WRITE_ONLY);
}
