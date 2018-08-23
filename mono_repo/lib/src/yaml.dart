// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
