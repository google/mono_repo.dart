// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Doing a copy-paste from JSON – which uses double-quotes
// ignore_for_file: prefer_single_quotes

import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:pubspek/pubspek.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:test/test.dart';

String _encodeJson(Object input) =>
    const JsonEncoder.withIndent(' ').convert(input);

Matcher _throwsParsedYamlException(String prettyValue) => throwsA(allOf(
    const isInstanceOf<ParsedYamlException>(),
    new FeatureMatcher<ParsedYamlException>('message', (e) {
      printOnFailure("r'''\n${e.message}'''");
      if (e.innerStack != null) {
        printOnFailure(Trace.format(e.innerStack, terse: true));
      }
      return e.message;
    }, prettyValue)));

Pubspec _parse(map) => parsePubspec(_encodeJson(map));

void _expectParseThrows(Object content, String expectedError) =>
    expect(() => _parse(content), _throwsParsedYamlException(expectedError));

void main() {
  test('trival', () {
    try {
      var thing = _parse({'name': 'sample'});
      expect(thing.name, 'sample');
      expect(thing.authors, isEmpty);
      expect(thing.dependencies, isEmpty);
    } on CheckedFromJsonException catch (e) {
      print([e.innerError, e.innerStack, e.map, e.key, e.className].join('\n'));
    }
  });

  test('one author', () {
    var thing = _parse({'name': 'sample', 'author': 'name@example.com'});
    expect(thing.allAuthors, ['name@example.com']);
  });

  test('one author, via authors', () {
    var thing = _parse({
      'name': 'sample',
      'authors': ['name@example.com']
    });
    expect(thing.authors, ['name@example.com']);
  });

  test('many authors', () {
    var thing = _parse({
      'name': 'sample',
      'authors': ['name@example.com', 'name2@example.com']
    });
    expect(thing.authors, ['name@example.com', 'name2@example.com']);
  });

  test('author and authors', () {
    var value = _parse({
      'name': 'sample',
      'author': 'name@example.com',
      'authors': ['name2@example.com']
    });
    expect(value.allAuthors, ['name@example.com', 'name2@example.com']);
  });

  group('invalid', () {
    test('missing name', () {
      _expectParseThrows({}, r'''
line 1, column 1: "name" cannot be empty.
{}
^^''');
    });

    test('"dart" is an invalid environment key', () {
      _expectParseThrows({
        'name': 'sample',
        'environment': {'dart': 'cool'}
      }, r'''
line 4, column 3: Use "sdk" to for Dart SDK constraints.
  "dart": "cool"
  ^^^^^^''');
    });

    test('invalid version', () {
      _expectParseThrows({'name': 'sample', 'version': 'invalid'}, r'''
line 3, column 13: Unsupported value for `version`.
 "version": "invalid"
            ^^^^^^^^^''');
    });

    test('invalid environment value', () {
      _expectParseThrows({
        'name': 'sample',
        'environment': {'sdk': 'silly'}
      }, r'''
line 4, column 10: Could not parse version "silly". Unknown text at "silly".
  "sdk": "silly"
         ^^^^^^^''');
    });
  });
}

// TODO(kevmoo) add this to pkg/matcher – is nice!
class FeatureMatcher<T> extends CustomMatcher {
  final dynamic Function(T value) _feature;

  FeatureMatcher(String name, this._feature, matcher)
      : super('`$name`', '`$name`', matcher);

  @override
  featureValueOf(covariant T actual) => _feature(actual);
}
