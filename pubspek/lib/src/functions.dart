// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

import 'errors.dart';
import 'pubspec.dart';

/// If [sourceUrl] is passed, it's used as the URL from which the YAML
/// originated for error reporting. It can be a [String], a [Uri], or `null`.
Pubspec parsePubspec(String yaml, {sourceUrl}) {
  var item = loadYaml(yaml, sourceUrl: sourceUrl);

  if (item is YamlMap) {
    try {
      return new Pubspec.fromJson(item);
    } on CheckedFromJsonException catch (error, stack) {
      var innerError = error.innerError;
      String message;

      if (innerError is BadKeyException) {
        var map = innerError.map;
        if (map is YamlMap) {
          var key = map.nodes.keys.singleWhere((key) {
            return (key as YamlScalar).value == innerError.key;
          }, orElse: () => null);

          if (key is YamlScalar) {
            message = key.span.message(innerError.message);
          }
        }
      }

      message ??= _prettyPrintCheckedFromJsonException(error);

      throw parsedYamlException(message,
          innerError: innerError ?? error,
          innerStack: error.innerStack ?? stack);
    }
  }

  throw new StateError('boo!');
}

String _prettyPrintCheckedFromJsonException(CheckedFromJsonException err) {
  var yamlMap = err.map as YamlMap;

  var yamlValue = yamlMap.nodes[err.key];

  String message;
  if (yamlValue == null) {
    assert(err.message != null);
    message = '${yamlMap.span.message(err.message.toString())}';
  } else {
    if (err.message == null) {
      message = 'Unsupported value for `${err.key}`.';
    } else {
      message = err.message.toString();
    }
    message = yamlValue.span.message(message);
  }

  return message;
}
