// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

ParsedYamlException parsedYamlException(String message,
        {Object innerError, StackTrace innerStack}) =>
    new ParsedYamlException._(message,
        innerError: innerError, innerStack: innerStack);

class BadKeyException implements Exception {
  final Map map;
  final String key;
  final String message;

  BadKeyException(this.map, this.key, this.message);
}

class ParsedYamlException implements Exception {
  final String message;
  final Object innerError;
  final StackTrace innerStack;

  ParsedYamlException._(this.message, {this.innerError, this.innerStack});

  @override
  String toString() => message;
}
