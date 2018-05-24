// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(kevmoo) - it'd be nice if this didn't have to be recreated
// https://github.com/dart-lang/pub/issues/1676

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

part 'pubspec.g.dart';

enum DependencyType { hosted, path, git, sdk }

abstract class DependencyData {
  DependencyType get type;

  factory DependencyData.fromJson(dynamic data) {
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

      final sdk = mapData['sdk'];
      if (sdk != null) {
        return new SdkData(sdk);
      }

      throw new ArgumentError.value(
          data, 'data', 'No clue how to deal with `$data`.');
    }
  }
}

class SdkData implements DependencyData {
  final String name;

  @override
  DependencyType get type => DependencyType.sdk;

  factory SdkData(Object data) {
    if (data is String) {
      return new SdkData._(data);
    } else {
      throw new ArgumentError.value(
          data, 'data', 'Does not support provided value.');
    }
  }

  SdkData._(this.name);
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
    } else if (data is Map) {
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

@JsonSerializable(createToJson: false)
class Pubspec {
  final String name;

  @JsonKey(fromJson: _versionFromString)
  final Version version;

  @JsonKey(fromJson: _getDeps, nullable: false)
  final Map<String, DependencyData> dependencies;

  @JsonKey(name: 'dev_dependencies', fromJson: _getDeps, nullable: false)
  final Map<String, DependencyData> devDependencies;

  @JsonKey(name: 'dependency_overrides', fromJson: _getDeps, nullable: false)
  final Map<String, DependencyData> dependencyOverrides;

  Pubspec(
      this.name,
      this.version,
      Map<String, DependencyData> dependencies,
      Map<String, DependencyData> devDependencies,
      Map<String, DependencyData> dependencyOverrides)
      : this.dependencies = dependencies ?? const {},
        this.devDependencies = devDependencies ?? const {},
        this.dependencyOverrides = dependencyOverrides ?? const {};

  factory Pubspec.fromJson(Map json) => _$PubspecFromJson(json);
}

Map<String, DependencyData> _getDeps(Map source) =>
    source?.map(
        (k, v) => new MapEntry(k as String, new DependencyData.fromJson(v))) ??
    {};

Version _versionFromString(String input) => new Version.parse(input);
