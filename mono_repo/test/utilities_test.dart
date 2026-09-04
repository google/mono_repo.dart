// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mono_repo/src/utilities.dart';
import 'package:test/test.dart';

void main() {
  group('compareSdks', () {
    test('identical strings return 0', () {
      expect(compareSdks('stable', 'stable'), 0);
      expect(compareSdks('3.0.0', '3.0.0'), 0);
      expect(compareSdks('pubspec', 'pubspec'), 0);
    });

    test('orders pubspec before SemVer and channels', () {
      expect(compareSdks('pubspec', '2.0.0'), lessThan(0));
      expect(compareSdks('2.0.0', 'pubspec'), greaterThan(0));
      expect(compareSdks('pubspec', 'stable'), lessThan(0));
      expect(compareSdks('stable', 'pubspec'), greaterThan(0));
    });

    test('orders channels correctly', () {
      final channels = ['main', 'dev', 'beta', 'stable']..sort(compareSdks);
      expect(channels, ['stable', 'beta', 'dev', 'main']);

      expect(compareSdks('main', 'master'), 0);
    });

    test('orders SemVer versions numerically', () {
      final versions = ['3.1.0', '2.19.0', '3.0.0', '2.9.0']..sort(compareSdks);
      expect(versions, ['2.9.0', '2.19.0', '3.0.0', '3.1.0']);
    });

    test('orders SemVer pre-releases before stable release', () {
      final versions = ['3.0.0', '3.0.0-0.1.dev', '3.0.0-1.0.beta']
        ..sort(compareSdks);
      expect(versions, ['3.0.0-0.1.dev', '3.0.0-1.0.beta', '3.0.0']);
    });

    test('orders SemVer before channels', () {
      expect(compareSdks('3.10.0', 'stable'), lessThan(0));
      expect(compareSdks('stable', '3.10.0'), greaterThan(0));
      expect(compareSdks('99.99.99', 'dev'), lessThan(0));
    });

    test('falls back to string compare for unparseable strings', () {
      expect(compareSdks('custom_a', 'custom_b'), lessThan(0));
      expect(compareSdks('custom_b', 'custom_a'), greaterThan(0));
    });

    test('sorts mixed collection of SDK targets', () {
      final sdks = [
        'main',
        'dev',
        'pubspec',
        '3.0.0',
        'stable',
        'beta',
        '2.19.0',
        'custom_b',
        'custom_a',
      ]..sort(compareSdks);
      expect(sdks, [
        'pubspec',
        '2.19.0',
        '3.0.0',
        'custom_a',
        'custom_b',
        'stable',
        'beta',
        'dev',
        'main',
      ]);
    });
  });
}
