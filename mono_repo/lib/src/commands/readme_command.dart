// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pubspec_parse/pubspec_parse.dart';

import '../root_config.dart';
import 'list_command.dart';
import 'mono_repo_command.dart';

class ReadmeCommand extends MonoRepoCommand {
  ReadmeCommand() {
    argParser
      ..addFlag(
        'only-published',
        abbr: 'p',
        help: 'Only list packages with a version and without publish_to set to '
            'none.',
      )
      ..addFlag(
        'pad',
        help: 'Pad table contents so cells in the same column are the same '
            'width.',
      );
  }

  @override
  String get name => 'readme';

  @override
  String get description =>
      'Generate a markdown table of all packages configured for mono_repo.';

  @override
  void run() => print(
        readme(
          rootConfig(),
          onlyPublished: argResults!['only-published'] as bool,
          pad: argResults!['pad'] as bool,
        ),
      );
}

String readme(
  RootConfig rootConfig, {
  required bool onlyPublished,
  required bool pad,
}) {
  final rows = [
    ['Package source', 'Description', 'Published Version'],
    for (var pkg in enumeratePackages(rootConfig, onlyPublished: onlyPublished))
      [
        '[${pkg.pubspec.name}](${pkg.relativePath}/)',
        pkg.pubspec.description ?? '',
        pkg.pubspec.pubBadge,
      ]
  ];

  final widths = [3, 3, 3];
  if (pad) {
    for (var row in rows) {
      for (var i = 0; i < 3; i++) {
        if (row[i].length > widths[i]) {
          widths[i] = row[i].length;
        }
      }
    }
    for (var row in rows) {
      for (var i = 0; i < 3; i++) {
        row[i] = row[i].padRight(widths[i]);
      }
    }
  }

  rows.insert(1, widths.map((e) => '-' * e).toList());

  return rows.map((e) => '| ${e.join(' | ')} |').join('\n');
}

extension on Pubspec {
  String get pubBadge => published(this)
      ? '[![pub package](https://img.shields.io/pub/v/$name.svg)](https://pub.dev/packages/$name)'
      : '';
}