// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../package_config.dart';
import '../root_config.dart';
import '../utilities.dart';
import 'mono_repo_command.dart';

class ListCommand extends MonoRepoCommand {
  ListCommand() {
    argParser
      ..addFlag(
        'only-published',
        abbr: 'p',
        help: 'Only list packages with a version and without publish_to set to '
            'none.',
      )
      ..addMultiOption(
        'show',
        abbr: 's',
        help:
            'The properties of the package to show in a comma-seperated list.',
        allowed: Column.values.map((e) => e.name),
        allowedHelp: {for (var item in Column.values) item.name: item.help},
        defaultsTo: Column.values
            .where((element) => element.defaultsTo)
            .map((e) => e.name),
      );
  }

  @override
  String get name => 'list';

  @override
  String get description => 'List all packages configured for mono_repo.';

  @override
  void run() => print(
        listPackages(
          rootConfig(),
          onlyPublished: argResults!['only-published'] as bool,
          showItems: (argResults!['show'] as List<String>)
              .map(
                (e) =>
                    Column.values.singleWhere((element) => element.name == e),
              )
              .toSet(),
        ).join('\n'),
      );
}

enum Column {
  name(
    help: 'The name of the package as specified in the "name" field.',
    defaultsTo: true,
  ),
  path(
    help: 'The path to the package relative to the root of the repository.',
    defaultsTo: true,
  ),
  version(
    help: 'The version of the package as specified in the "version" field.',
    defaultsTo: false,
  ),
  publishTo(
    help: 'The value of the "publish_to" field.',
    defaultsTo: false,
  );

  const Column({
    required this.help,
    required this.defaultsTo,
  });

  final String help;
  final bool defaultsTo;

  String valueFor(PackageConfig cfg) {
    switch (this) {
      case Column.name:
        return cfg.pubspec.name;
      case Column.path:
        return cfg.relativePath;
      case Column.version:
        return cfg.pubspec.version?.toString() ?? '';
      case Column.publishTo:
        return cfg.pubspec.publishTo ?? '';
    }
  }
}

Iterable<String> listPackages(
  RootConfig rootConfig, {
  required bool onlyPublished,
  required Set<Column> showItems,
}) sync* {
  for (var pkg in enumeratePackages(rootConfig, onlyPublished: onlyPublished)) {
    yield showItems.map((e) => e.valueFor(pkg)).join(',');
  }
}

Iterable<PackageConfig> enumeratePackages(
  RootConfig rootConfig, {
  required bool onlyPublished,
}) =>
    rootConfig.where((element) => !onlyPublished || element.pubspec.published);
