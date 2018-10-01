// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart' as y;

import 'user_exception.dart';

final _yamlMapExpando = new Expando<y.YamlMap>('yamlMap');

String prettyPrintCheckedFromJsonException(CheckedFromJsonException err) {
  var yamlMap = _yamlMapExpando[err.map];
  if (yamlMap == null) {
    return null;
  }

  y.YamlScalar _getYamlKey(String key) => yamlMap.nodes.keys
      .cast<y.YamlScalar>()
      .singleWhere((k) => k.value == key, orElse: () => null);

  var yamlKey = _getYamlKey(err.key);

  String message;
  if (yamlKey == null) {
    if (err.innerError is UnrecognizedKeysException) {
      var innerError = err.innerError as UnrecognizedKeysException;
      message = '${innerError.message}';
      for (var key in innerError.unrecognizedKeys) {
        var yamlKey = _getYamlKey(key);
        assert(yamlKey != null);
        message += '\n${yamlKey.span.message('Unrecognized key "$key"')}';
      }
    } else {
      assert(err.message != null);
      message = '${yamlMap.span.message(err.message.toString())}';
    }
  } else {
    if (err.message == null) {
      message = 'Unsupported value for `${err.key}`.';
    } else {
      message = err.message.toString();
    }
    message = yamlKey.span.message(message);
  }

  return message;
}

/// If the file at `[rootDir]/[relativeFilePath]` does not exist, `null` is
/// returned.
///
/// Otherwise,
///   - if its content is a [Map], the map is returned.
///   - if its content is `null`, an empty [Map] is returned.
///   - if its content is anything else, a [UserException] is thrown.
Map yamlMapOrNull(String rootDir, String relativeFilePath) {
  var yamlFile = new File(p.join(rootDir, relativeFilePath));

  if (yamlFile.existsSync()) {
    var pkgConfigYaml = loadYamlOrdered(yamlFile.readAsStringSync(),
        sourceUrl: relativeFilePath);

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

/// Returns [source] parsed as Yaml, but with [Map] instances having keys
/// ordered by their location in the input.
///
/// `package:yaml` follows Yaml 1.2 spec strictly and does not honor the input
/// ordering for [Map] keys, hence this work-around.
Object loadYamlOrdered(String source, {dynamic sourceUrl}) {
  Object convertOrdered(Object yaml) {
    if (yaml == null || yaml is String || yaml is num || yaml is bool) {
      return yaml;
    }
    if (yaml is y.YamlList) {
      return yaml.map(convertOrdered).toList();
    }
    if (yaml is y.YamlMap) {
      var keys = yaml.keys.toList();
      keys.sort((a, b) {
        var aNode = yaml.nodes[a];
        var bNode = yaml.nodes[b];

        return aNode.span.compareTo(bNode.span);
      });
      var map = Map.fromIterable(keys, value: (k) => convertOrdered(yaml[k]));
      _yamlMapExpando[map] = yaml;
      return map;
    }

    throw UnsupportedError(
        'Cannot convert output of type ${yaml.runtimeType}.');
  }

  var yaml = y.loadYaml(source, sourceUrl: sourceUrl);
  return convertOrdered(yaml);
}

String toYaml(Object source) {
  var buffer = new StringBuffer();
  _writeYaml(buffer, source, 0, false);
  return buffer.toString();
}

String _escapeString(String source) {
  if (_simpleString.hasMatch(source) &&
      !source.startsWith(_maybeNumber) &&
      !_escapeRegExp.hasMatch(source) &&
      source.trim() == source && // no leading or trailing whitespace
      source.codeUnits.every((i) => i < 128) && // quote all non-ascii Strings
      !_yamlSpecialStrings.contains(source.toLowerCase())) {
    return source;
  }
  var output = source.replaceAllMapped(_escapeRegExp, (match) {
    var value = match[0];
    return _escapeMap[value] ?? _getHexLiteral(value);
  }).replaceAll('"', r'\"');

  return '"$output"';
}

bool _isSimple(Object source) =>
    source == null || source is bool || source is num || source is String;

void _writeYaml(
    StringBuffer buffer, Object source, int indent, bool parentIsMap) {
  final spaces = '  ' * indent;
  if (source is String) {
    buffer.write(_escapeString(source));
  } else if (source == null || source is bool || source is num) {
    buffer.write(source);
  } else if (source is Map) {
    if (source.isEmpty) {
      if (parentIsMap) {
        // Need to ensure there is a space after the map `key:`
        buffer.write(' ');
      }
      buffer.write('{}');
    } else {
      var first = true;
      for (var entry in source.entries) {
        String keyLiteral;
        if (entry.key is String) {
          keyLiteral = _escapeString(entry.key as String);
        } else if (_isSimple(entry.key)) {
          keyLiteral = entry.key.toString();
        } else {
          throw ArgumentError('Map keys must be simple literals.');
        }

        if (first && !parentIsMap) {
          buffer.write('$keyLiteral:');
        } else {
          buffer.writeln();
          buffer.write('$spaces$keyLiteral:');
        }

        if (first) {
          first = false;
        }

        if (_isSimple(entry.value)) {
          buffer.write(' ');
          _writeYaml(buffer, entry.value, 0, true);
        } else {
          _writeYaml(buffer, entry.value, indent + 1, true);
        }
      }
    }
  } else if (source is Iterable) {
    if (source.isEmpty) {
      if (parentIsMap) {
        // Need to ensure there is a space after the map `key:`
        buffer.write(' ');
      }
      buffer.write('[]');
    } else {
      var first = true;
      for (var item in source) {
        if (first) {
          if (parentIsMap) {
            buffer.writeln();
          }
          first = false;
        } else {
          buffer.writeln();
        }
        buffer.write('$spaces- ');
        if (_isSimple(item)) {
          _writeYaml(buffer, item, indent, false);
        } else {
          _writeYaml(buffer, item, indent + 1, false);
        }
      }
    }
  } else {
    throw UnsupportedError('We do not like ${source.runtimeType}');
  }
}

/// Strings that have special meaning in Yaml
///
/// Note: "yes" and "no" are not treated as `true`/`false` in pkg:yaml, but
/// they are in many other parsers.
///
/// See http://yaml.org/spec/1.2/spec.html#id2805071
/// `...` is from http://yaml.org/spec/1.2/spec.html#id2760395
const _yamlSpecialStrings = ['true', 'false', 'null', '...', 'yes', 'no'];

/// See http://yaml.org/spec/1.2/spec.html#id2772075
final _yamlIndicators = [
  '-',
  '?',
  ':',
  ',',
  '[',
  ']',
  '{',
  '}',
  '#',
  '&',
  '*',
  '!',
  '|',
  '>',
  "'",
  '%',
  '@',
  '`',
].map(RegExp.escape).join();

final _simpleString =
    RegExp('^[^${_yamlIndicators}0-9"~][^$_yamlIndicators]*\$');

final _maybeNumber = RegExp(r'\+?\.?\d');

/// A [Map] between whitespace characters & `\` and their escape sequences.
const _escapeMap = {
  '\b': r'\b', // 08 - backspace
  '\t': r'\t', // 09 - tab
  '\n': r'\n', // 0A - new line
  '\v': r'\v', // 0B - vertical tab
  '\f': r'\f', // 0C - form feed
  '\r': r'\r', // 0D - carriage return
  '\x7F': r'\x7F', // delete
  r'\': r'\\' // backslash
};

final _escapeMapRegexp = _escapeMap.keys.map(_getHexLiteral).join();

/// A [RegExp] that matches whitespace characters
final _escapeRegExp = RegExp('[\\x00-\\x07\\x0E-\\x1F$_escapeMapRegexp]');

/// Given single-character string, return the hex-escaped equivalent.
String _getHexLiteral(String input) {
  var rune = input.runes.single;
  var value = rune.toRadixString(16).toUpperCase().padLeft(2, '0');
  return '\\x$value';
}
