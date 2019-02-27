// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mono_repo/src/shell_utils.dart';
import 'package:test/test.dart';

void main() {
  group('safeEcho', () {
    for (var entry in {
      'hello': "echo -e 'hello'",
      "single-quotes 'inside' the string":
          "echo -e 'single-quotes '\\''inside'\\'' the string'",
      "'single quotes' at the beginning 'middle' and at the 'end'":
          "echo -e ''\\''single quotes'\\'' at the beginning '\\''middle'\\'' and at the '\\''end'\\'''",
      "Repeated single quotes ''' in the '' middle":
          "echo -e 'Repeated single quotes '\\'''\\'''\\'' in the '\\'''\\'' middle'",
    }.entries) {
      test(entry.key, () {
        expect(safeEcho(false, null, entry.key), entry.value);
      });
    }
  });
}
