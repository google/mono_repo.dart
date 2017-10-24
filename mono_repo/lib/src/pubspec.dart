// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(kevmoo) - it'd be nice if this didn't have to be recreated
// https://github.com/dart-lang/pub/issues/1676

import 'package:pub_semver/pub_semver.dart';

class Dependency {
  final String name;
  final DependencyData data;

  Dependency(this.name, this.data);

  factory Dependency.parse(String name, dynamic data) {
    var dd = new DependencyData(data);

    return new Dependency(name, dd);
  }
}

enum DependencyType { hosted, path, git }

abstract class DependencyData {
  DependencyType get type;

  factory DependencyData(dynamic data) {
    if (data == null) {
      return new HostedData(VersionConstraint.any);
    } else if (data is String) {
      return new HostedData(new VersionConstraint.parse(data));
    } else {
      var mapData = data as Map;

      var path = mapData['path'] as String;
      if (path != null) {
        return new PathData(path);
      }

      var git = mapData['git'];
      if (git != null) {
        return new GitData.fromData(git);
      }

      throw new ArgumentError.value(
          data, 'data', 'No clue how to deal with `$data`.');
    }
  }
}

class GitData implements DependencyData {
  @override
  DependencyType get type => DependencyType.git;

  final Uri url;
  final String ref;
  final String path;

  GitData(this.url, this.ref, this.path);

  factory GitData.fromData(Object data) {
    String url;
    String path;
    String ref;

    if (data is String) {
      url = data;
    } else if (data is Map<String, dynamic>) {
      url = data['url'] as String;
      path = data['path'] as String;
      ref = data['ref'] as String;
    } else {
      throw new ArgumentError.value(
          data, 'data', 'Does not support provided value.');
    }

    return new GitData(Uri.parse(url), ref, path);
  }

  @override
  String toString() => 'GitData: url@$url';
}

class PathData implements DependencyData {
  @override
  DependencyType get type => DependencyType.path;

  final String path;

  PathData(this.path);

  @override
  String toString() => 'PathData: path@$path';
}

// TODO: support explicit host?
class HostedData implements DependencyData {
  @override
  DependencyType get type => DependencyType.hosted;

  final VersionConstraint constraint;

  HostedData(this.constraint);
}

class Pubspec {
  final String name;
  final Version version;

  final Map<String, Dependency> dependencies,
      devDependencies,
      dependencyOverrides;

  Pubspec(
      this.name,
      this.version,
      Map<String, Dependency> dependencies,
      Map<String, Dependency> devDependencies,
      Map<String, Dependency> dependencyOverrides)
      : this.dependencies = dependencies ?? {},
        this.devDependencies = devDependencies ?? {},
        this.dependencyOverrides = dependencyOverrides ?? {};

  factory Pubspec.fromJson(Map<String, dynamic> json) {
    var versionStr = json['version'] as String;
    Version version;
    if (versionStr != null) {
      version = new Version.parse(versionStr);
    }

    return new Pubspec(
        json['name'] as String,
        version,
        _getDependencies(json['dependencies'] as Map<String, dynamic>),
        _getDependencies(json['dev_dependencies'] as Map<String, dynamic>),
        _getDependencies(json['dependency_overrides'] as Map<String, dynamic>));
  }

  static Map<String, Dependency> _getDependencies(Map<String, dynamic> json) {
    if (json == null) {
      return null;
    }

    var deps = <String, Dependency>{};
    json.forEach((k, v) {
      deps[k] = new Dependency.parse(k, v);
    });

    return deps;
  }
}
