// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pub_semver/pub_semver.dart';

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
