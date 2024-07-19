// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// On windows this test fails for unknown reasons, possibly there are carriage
// returns being introduced during formatting.
@OnPlatform({'windows': Skip('Broken on windows')})
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('action versions are up to date', () {
    final result = Process.runSync(
      Platform.executable,
      ['tool/generate_action_versions.dart', '--validate'],
    );
    expect(result.exitCode, 0, reason: result.stdout as String);
  });
}
