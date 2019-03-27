// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:io/ansi.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import '../root_config.dart';
import 'mono_repo_command.dart';

class CheckCommand extends MonoRepoCommand {
  @override
  String get name => 'check';

  @override
  String get description => 'Check the state of the repository.';

  @override
  Future<void> run() => check(rootConfig());
}

Future<void> check(RootConfig rootConfig) async {
  final reports = getPackageReports(rootConfig);

  print(styleBold.wrap('    ** REPORT **'));
  print('');

  reports.forEach(_print);
}

Map<String, PackageReport> getPackageReports(RootConfig rootConfig) {
  final siblings = rootConfig.map((pc) => pc.pubspec).toSet();
  return Map.fromEntries(rootConfig.map((p) =>
      MapEntry(p.relativePath, PackageReport.create(p.pubspec, siblings))));
}

void _print(String relativePath, PackageReport report) {
  print('$relativePath/');
  print('       name: ${report.packageName}');
  print('  published: ${report.published}');
  if (report.version != null) {
    var value = '    version: ${report.version}';
    if (report.version.isPreRelease) {
      value = yellow.wrap(value);
    }
    print(value);
  }
  if (report.siblings.isNotEmpty) {
    print('   siblings:');
    report.siblings.forEach((k, v) {
      var value = '     $k: $v';
      if (report.published && v.overrideData != null) {
        value = yellow.wrap(value);
      }
      print(value);
    });
  }
  print('');
}

class PackageReport {
  final Pubspec pubspec;
  final Map<String, SiblingReference> siblings;

  // TODO: use `publish_to` when available - dart-lang/pubspec_parse#21
  bool get published => pubspec.version != null;

  String get packageName => pubspec.name;
  Version get version => pubspec.version;

  PackageReport(this.pubspec, this.siblings);

  factory PackageReport.create(Pubspec pubspec, Set<Pubspec> siblings) {
    // TODO(kevmoo): check: if any dependency has a path dependency, it'd better
    // be a sibling – right?

    final sibs = <String, SiblingReference>{};
    for (var sib in siblings) {
      final ref = SiblingReference.create(pubspec, sib);

      if (ref != null) {
        sibs[sib.name] = ref;
      }
    }

    return PackageReport(pubspec, sibs);
  }
}

enum DependencyType { direct, dev, indirect }

class SiblingReference {
  final DependencyType type;
  final Dependency normalData;
  final Dependency overrideData;

  SiblingReference(this.type, this.normalData, this.overrideData);

  factory SiblingReference.create(Pubspec sourcePubspec, Pubspec sibling) {
    for (var dep in sourcePubspec.dependencies.entries) {
      if (dep.key == sibling.name) {
        // a match!
        final override = sourcePubspec.dependencyOverrides.entries
            .firstWhere((d) => d.key == dep.key, orElse: () => null);
        return SiblingReference(
            DependencyType.direct, dep.value, override?.value);
      }
    }
    for (var dep in sourcePubspec.devDependencies.entries) {
      if (dep.key == sibling.name) {
        // a match!
        final override = sourcePubspec.dependencyOverrides.entries
            .firstWhere((d) => d.key == dep.key, orElse: () => null);
        return SiblingReference(DependencyType.dev, dep.value, override?.value);
      }
    }
    for (var dep in sourcePubspec.dependencyOverrides.entries) {
      if (dep.key == sibling.name) {
        return SiblingReference(DependencyType.indirect, null, dep.value);
      }
    }
    return null;
  }

  @override
  String toString() {
    final items = [type.toString().split('.')[1]];

    if (overrideData != null) {
      items.add('overridden');
    }

    return items.join(', ');
  }
}
