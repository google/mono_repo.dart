import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

import 'package_config.dart';
import 'pubspec.dart';
import 'utils.dart';

class CheckCommand extends Command {
  @override
  String get name => 'check';

  @override
  String get description => 'Check the state of the repository.';

  @override
  Future run() => check();
}

Future check() async {
  var packages = getPackageConfig();

  var pubspecs = <String, Pubspec>{};
  packages.forEach((dir, config) {
    var pkgPath = p.join(p.current, dir, 'pubspec.yaml');
    var pubspecContent = y.loadYaml(new File(pkgPath).readAsStringSync())
        as Map<String, dynamic>;

    var pubspec = new Pubspec.fromJson(pubspecContent);

    // TODO: should enforce that all "covered" pubspecs have different names
    // in their pubspec.yaml file? Certainly all published packages
    pubspecs[dir] = pubspec;
  });

  var pubspecValues = pubspecs.values.toSet();

  print("    ** Report **\n");
  packages.forEach((dir, config) {
    var report = new PackageReport.create(config, pubspecs[dir], pubspecValues);
    _print(dir, report);
  });
}

void _print(String relativePath, PackageReport report) {
  print("$relativePath/");
  print("       name: ${report.packageName}");
  print("  published: ${report.published}");
  if (report.version != null) {
    print("    version: ${report.version}");
  }
  print('');
}

class PackageReport {
  final PackageConfig config;
  final Pubspec pubspec;

  bool get published => config.published;

  String get packageName => pubspec.name;
  Version get version => pubspec.version;

  PackageReport(this.config, this.pubspec);

  factory PackageReport.create(
      PackageConfig config, Pubspec pubspec, Set<Pubspec> siblings) {
    // TODO(kevmoo): check: if any dependency has a path dependency, it'd better
    // be a sibling – right?

    var references = siblings
        .map((ps) => new SiblingReference.create(pubspec, ps))
        .where((sr) => sr != null)
        .toList();

    print("${pubspec.name}: ${references.join(', ')}");

    return new PackageReport(config, pubspec);
  }
}

enum DependencyType { direct, dev, indirect }

class SiblingReference {
  final String name;
  final DependencyType type;
  final DependencyData normalData;
  final DependencyData overrideData;

  SiblingReference(this.name, this.type, this.normalData, this.overrideData);

  factory SiblingReference.create(Pubspec sourcePubspec, Pubspec sibling) {
    for (var dep in sourcePubspec.dependencies.values) {
      if (dep.name == sibling.name) {
        // a match!
        var override = sourcePubspec.dependencyOverrides.values
            .firstWhere((d) => d.name == dep.name, orElse: () => null);
        return new SiblingReference(
            dep.name, DependencyType.direct, dep.data, override?.data);
      }
    }
    for (var dep in sourcePubspec.devDependencies.values) {
      if (dep.name == sibling.name) {
        // a match!
        var override = sourcePubspec.dependencyOverrides.values
            .firstWhere((d) => d.name == dep.name, orElse: () => null);
        return new SiblingReference(
            dep.name, DependencyType.dev, dep.data, override?.data);
      }
    }
    for (var dep in sourcePubspec.dependencyOverrides.values) {
      if (dep.name == sibling.name) {
        return new SiblingReference(
            dep.name, DependencyType.indirect, null, dep.data);
      }
    }
    return null;
  }

  @override
  String toString() {
    var buffer = new StringBuffer(name);

    var items = [type.toString().split('.')[1]];

    if (overrideData != null) {
      items.add("overridden");
    }

    buffer.write(" (${items.join(', ')})");

    return buffer.toString();
  }
}
