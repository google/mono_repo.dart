// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

import 'dependency_data.dart';
import 'errors.dart';

part 'pubspec.g.dart';

@JsonSerializable(createToJson: false)
class Pubspec {
  final String name;
  final String homepage;
  final String documentation;
  final String description;
  final String author;
  final List<String> authors;

  @JsonKey(fromJson: _environmentMap)
  final Map<String, VersionConstraint> environment;

  List<String> get allAuthors {
    var values = <String>[];
    if (author != null) {
      values.add(author);
    }
    values.addAll(authors);
    return values;
  }

  @JsonKey(fromJson: _versionFromString)
  final Version version;

  @JsonKey(fromJson: _getDeps, nullable: false)
  final Map<String, DependencyData> dependencies;

  @JsonKey(name: 'dev_dependencies', fromJson: _getDeps, nullable: false)
  final Map<String, DependencyData> devDependencies;

  @JsonKey(name: 'dependency_overrides', fromJson: _getDeps, nullable: false)
  final Map<String, DependencyData> dependencyOverrides;

  Pubspec(
    this.name, {
    this.version,
    this.author,
    this.environment,
    List<String> authors,
    String homepage,
    String documentation,
    String description,
    Map<String, DependencyData> dependencies,
    Map<String, DependencyData> devDependencies,
    Map<String, DependencyData> dependencyOverrides,
  })  : this.authors = authors ?? const [],
        this.homepage = homepage?.trim(),
        this.description = description?.trim(),
        this.documentation = documentation?.trim(),
        this.dependencies = dependencies ?? const {},
        this.devDependencies = devDependencies ?? const {},
        this.dependencyOverrides = dependencyOverrides ?? const {} {
    if (name == null || name.isEmpty) {
      throw new ArgumentError.value(name, 'name', '"name" cannot be empty.');
    }
  }

  factory Pubspec.fromJson(Map json) => _$PubspecFromJson(json);
}

Map<String, DependencyData> _getDeps(Map source) =>
    source?.map(
        (k, v) => new MapEntry(k as String, new DependencyData.fromJson(v))) ??
    {};

Version _versionFromString(String input) => new Version.parse(input);

Map<String, VersionConstraint> _environmentMap(Map source) =>
    source.map((key, value) {
      if (key == 'dart') {
        // github.com/dart-lang/pub/blob/d84173eeb03c3/lib/src/pubspec.dart#L342
        // 'dart' is not allowed as a key!
        throw new BadKeyException(
            source, 'dart', 'Use "sdk" to for Dart SDK constraints.');
      }

      VersionConstraint constraint;
      try {
        constraint = new VersionConstraint.parse(value as String);
      } on FormatException catch (e) {
        throw new CheckedFromJsonException(
            source, key as String, 'Pubspec', e.message);
      }

      return new MapEntry(key as String, constraint);
    });
