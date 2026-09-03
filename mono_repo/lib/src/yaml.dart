// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;
import 'package:yaml_writer/yaml_writer.dart';

import 'user_exception.dart';

final _yamlMapExpando = Expando<y.YamlMap>('yamlMap');

abstract class YamlLike {
  Object? toJson();
}

/// Returns a new [Map] with the contents of [source], storing the original
/// [source] in an [Expando] allowing it be retrieved later in error handling
/// code to create more helpful errors.
Map<String, dynamic> transferYamlMap(y.YamlMap source) {
  final newMap = Map<String, dynamic>.from(source);
  _yamlMapExpando[newMap] = source;
  return newMap;
}

Map<String, dynamic> setYamlMapContext(
  Map<String, dynamic> target,
  y.YamlMap source,
) {
  _yamlMapExpando[target] = source;
  return target;
}

T createWithCheck<T>(T Function() constructor) {
  try {
    return constructor();
  } on CheckedFromJsonException catch (e) {
    final details = toParsedYamlExceptionOrNull(e);
    if (details == null) {
      rethrow;
    }
    throw details;
  }
}

ParsedYamlException? toParsedYamlExceptionOrNull(
  CheckedFromJsonException exception,
) {
  final yamlMap = exception.map is y.YamlMap
      ? exception.map as y.YamlMap
      : _yamlMapExpando[exception.map];
  if (yamlMap == null) {
    return null;
  }

  return toParsedYamlException(exception, exceptionMap: yamlMap);
}

/// If the file at `[rootDir]/[relativeFilePath]` does not exist, `null` is
/// returned.
///
/// Otherwise,
///   - if its content is a [Map], the map is returned.
///   - if its content is `null`, an empty [Map] is returned.
///   - if its content is anything else, a [UserException] is thrown.
Map? yamlMapOrNull(String rootDir, String relativeFilePath) {
  final yamlFile = File(p.join(rootDir, relativeFilePath));

  if (yamlFile.existsSync()) {
    final pkgConfigYaml = loadYamlChecked(
      yamlFile.readAsStringSync(),
      sourceUrl: Uri.parse(relativeFilePath),
    );

    if (pkgConfigYaml == null) {
      return {};
    } else if (pkgConfigYaml is Map) {
      return pkgConfigYaml;
    } else {
      throw UserException('The contents of `$relativeFilePath` must be a Map.');
    }
  }
  return null;
}

/// Returns [source] parsed as Yaml, but tries to convert thrown
/// [y.YamlException] instances to [ParsedYamlException] instances.
Object? loadYamlChecked(String source, {Uri? sourceUrl}) {
  try {
    return y.loadYaml(source, sourceUrl: sourceUrl);
  } on y.YamlException catch (e) {
    throw ParsedYamlException.fromYamlException(e);
  }
}

String toYaml(Object? source) => YamlWriter().write(source);
