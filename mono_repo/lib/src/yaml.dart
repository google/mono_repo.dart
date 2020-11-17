// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

import 'user_exception.dart';

final _yamlMapExpando = Expando<y.YamlMap>('yamlMap');

/// Returns a new [Map] with the contents of [source], storing the original
/// [source] in an [Expando] allowing it be retrieved later in error handling
/// code to create more helpful errors.
Map<String, dynamic> transferYamlMap(y.YamlMap source) {
  final newMap = Map<String, dynamic>.from(source);
  _yamlMapExpando[newMap] = source;
  return newMap;
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

ParsedYamlException toParsedYamlExceptionOrNull(
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
Map yamlMapOrNull(String rootDir, String relativeFilePath) {
  final yamlFile = File(p.join(rootDir, relativeFilePath));

  if (yamlFile.existsSync()) {
    final pkgConfigYaml = loadYamlOrdered(
      yamlFile.readAsStringSync(),
      sourceUrl: relativeFilePath,
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
// TODO: rename this to `loadYamlChecked` – more accurate
Object loadYamlOrdered(String source, {dynamic sourceUrl}) {
  try {
    return y.loadYaml(source, sourceUrl: sourceUrl);
  } on y.YamlException catch (e) {
    throw ParsedYamlException.fromYamlException(e);
  }
}

String toYaml(Object source) {
  final buffer = StringBuffer();
  _writeYaml(buffer, source, 0, null);
  return buffer.toString();
}

final _trivialSymbols = {'-', '@', '_', '/', '.'}.map(RegExp.escape).join();

// Characters that are okay to end a String starting with [a-zA-Z]
final _trivialSection = 'a-zA-Z\$0-9$_trivialSymbols';

final _trivialString = RegExp(
  // A String starting with [a-zA-Z]
  r'^[a-zA-Z$]'
  // Starting a non-capture group
  '(?:'
  // One of...
  // (a) [_trivialSection or space]+ followed by a _trivialSection
  '(?:[$_trivialSection ]+[$_trivialSection])'
  // or
  '|'
  // (b) any number of _trivialSection
  '(?:[$_trivialSection]*)'
  // End parent capture group
  ')'
  // End String
  r'$',
);

bool _isSimpleString(String input) =>
    _trivialString.hasMatch(input) || _simpleString.hasMatch(input);

String _escapeString(String source) {
  if (_isSimpleString(source) &&
      !source.startsWith(_maybeNumber) &&
      !_escapeRegExp.hasMatch(source) &&
      source.trim() == source && // no leading or trailing whitespace
      source.codeUnits.every((i) => i < 128) && // quote all non-ascii Strings
      !_yamlSpecialStrings.contains(source.toLowerCase())) {
    return source;
  }
  final output = source.replaceAllMapped(_escapeRegExp, (match) {
    final value = match[0];
    return _escapeMap[value] ?? _getHexLiteral(value);
  }).replaceAll('"', r'\"');

  return '"$output"';
}

bool _isSimple(Object source) =>
    source == null || source is bool || source is num || source is String;

enum _ParentType { list, map }

void _writeYaml(
  StringBuffer buffer,
  Object source,
  int indent,
  _ParentType parentType,
) {
  final spaces = '  ' * indent;
  if (source is String) {
    buffer.write(_escapeString(source));
  } else if (source == null || source is bool || source is num) {
    buffer.write(source);
  } else if (source is Map) {
    if (source.isEmpty) {
      if (parentType == _ParentType.map) {
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

        if (first && parentType != _ParentType.map) {
          buffer.write('$keyLiteral:');
        } else {
          buffer
            ..writeln()
            ..write('$spaces$keyLiteral:');
        }

        if (first) {
          first = false;
        }

        if (entry.value == null) {
          // skip it!
        } else if (_isSimple(entry.value)) {
          buffer.write(' ');
          _writeYaml(buffer, entry.value, 0, _ParentType.map);
        } else {
          _writeYaml(buffer, entry.value, indent + 1, _ParentType.map);
        }
      }
    }
  } else if (source is Iterable) {
    if (parentType == _ParentType.list && source.isNotEmpty) {
      throw UnsupportedError('We cannot encode lists within lists – yet!');
    }
    if (source.isEmpty) {
      if (parentType == _ParentType.map) {
        // Need to ensure there is a space after the map `key:`
        buffer.write(' ');
      }
      buffer.write('[]');
    } else if (source.length == 1 && _isSimple(source.single)) {
      // Write out 1-element, simple arrays compactly
      if (parentType == _ParentType.map) {
        // Need to ensure there is a space after the map `key:`
        buffer.write(' ');
      }
      buffer.write('[');
      _writeYaml(buffer, source.single, 0, _ParentType.list);
      buffer.write(']');
    } else {
      var first = true;
      for (var item in source) {
        if (first) {
          if (parentType == _ParentType.map) {
            buffer.writeln();
          }
          first = false;
        } else {
          buffer.writeln();
        }
        buffer.write('$spaces- ');
        if (_isSimple(item)) {
          _writeYaml(buffer, item, indent, _ParentType.list);
        } else {
          _writeYaml(buffer, item, indent + 1, _ParentType.list);
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
const _yamlSpecialStrings = {'true', 'false', 'null', '...', 'yes', 'no'};

/// See http://yaml.org/spec/1.2/spec.html#id2772075
final _yamlIndicators = {
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
}.map(RegExp.escape).join();

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
  final rune = input.runes.single;
  final value = rune.toRadixString(16).toUpperCase().padLeft(2, '0');
  return '\\x$value';
}
