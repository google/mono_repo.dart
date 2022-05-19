// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pubspec_parse/pubspec_parse.dart';

import '../package_config.dart';
import '../root_config.dart';
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
        allowed: ShowItem.values.map((e) => e.name),
        allowedHelp: Map.fromEntries(
          ShowItem.values.map((e) => MapEntry(e.name, e.help)),
        ),
        defaultsTo: ShowItem.values
            .where((element) => element.defaultsTo)
            .map((e) => e.name),
      );
  }

  @override
  String get name => 'list';

  @override
  String get description => 'List all packages configured for mono_repo.';

  @override
  void run() => print(listPackages(
        rootConfig(),
        onlyPublished: argResults!['only-published'] as bool,
        showItems: (argResults!['show'] as List<String>)
            .map((e) =>
                ShowItem.values.singleWhere((element) => element.name == e))
            .toSet(),
      ).join('\n'));
}

enum ShowItem {
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

  const ShowItem({
    required this.help,
    required this.defaultsTo,
  });

  final String help;
  final bool defaultsTo;

  String valueFor(PackageConfig cfg) {
    switch (this) {
      case ShowItem.name:
        return cfg.pubspec.name;
      case ShowItem.path:
        return cfg.relativePath;
      case ShowItem.version:
        return cfg.pubspec.version?.toString() ?? '';
      case ShowItem.publishTo:
        return cfg.pubspec.publishTo ?? '';
    }
  }
}

Iterable<String> listPackages(
  RootConfig rootConfig, {
  required bool onlyPublished,
  required Set<ShowItem> showItems,
}) sync* {
  for (var pkg in rootConfig) {
    if (onlyPublished && !_published(pkg.pubspec)) {
      continue;
    }
    yield showItems.map((e) => e.valueFor(pkg)).join(',');
  }
}

bool _published(Pubspec pubspec) =>
    pubspec.version != null && pubspec.publishTo != 'none';
