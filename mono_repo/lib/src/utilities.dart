// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'package_flavor.dart';

const travisEdgeSdk = 'be/raw/latest';

/// Maps to `be/raw/latest` or "bleeding edge".
const githubSetupMainSdk = 'main';

/// SDK version key to tell the generator to align with what's defined in
/// the pubspec.
const _pubspecSdkKey = 'pubspec';

String? errorForSdkConfig(PackageFlavor flavor, String sdk) {
  try {
    Version.parse(sdk);
    return null;
  } on FormatException {
    switch (flavor) {
      case PackageFlavor.dart:
        if (!_supportedDartSdkLiterals.contains(sdk)) {
          return 'The value "$sdk" is neither a version string nor one of '
              '$_dartSdkLiteralsPretty.';
        }
        return null;
      case PackageFlavor.flutter:
        if (!_supportedFlutterSdkLiterals.contains(sdk)) {
          return 'The value "$sdk" is neither a version string nor one of '
              '$_flutterLiteralsPretty.';
        }
        return null;
      default:
        throw UnsupportedError('should never get a flavor of `$flavor`');
    }
  }
}

/// Replaces instances of [_pubspecSdkKey] in [sdks] with the lower-bound
/// SDK constraint from [pubspec].
void handlePubspecInSdkList(
  PackageFlavor flavor,
  List<String>? sdks,
  Pubspec pubspec,
  Object Function(String message) errorFactory,
) {
  if (sdks == null) {
    return;
  }

  final sdkConstraint = pubspec.environment?['sdk'];

  Version? lowerVersion;
  if (sdkConstraint is VersionRange && sdkConstraint.includeMin) {
    lowerVersion = sdkConstraint.min;
  }

  for (var i = 0; i < sdks.length; i++) {
    final startValue = sdks[i];
    if (startValue == _pubspecSdkKey) {
      if (flavor != PackageFlavor.dart) {
        // ignore: only_throw_errors
        throw errorFactory(
          '`$_pubspecSdkKey` is only valid for Dart packages (not Flutter).',
        );
      }

      if (lowerVersion != null) {
        sdks[i] = lowerVersion.toString();
      } else {
        // TODO: throw a more specific error when the SDK constraint is not of
        //   the supported types
        // ignore: only_throw_errors
        throw errorFactory(
          '`$_pubspecSdkKey` is only valid for packages that have an '
          'environment->sdk value defined in `pubspec.yaml`.',
        );
      }
    }
  }
}

void sortNormalizeVerifySdksList(
  PackageFlavor flavor,
  List<String> sdks,
  Object Function(String message) errorFactory,
) {
  sdks.sort();
  for (var i = 0; i < sdks.length; i++) {
    var value = sdks[i];
    if (flavor == PackageFlavor.dart && _allowedMainVersions.contains(value)) {
      sdks[i] = value = githubSetupMainSdk;
    }
    final error = errorForSdkConfig(flavor, value);
    if (error != null) {
      // ignore: only_throw_errors
      throw errorFactory(error);
    }

    if (i > 0 && value == sdks[i - 1]) {
      // ignore: only_throw_errors
      throw errorFactory('"$value" appears more than once.');
    }
  }
}

const _supportedFlutterSdkLiterals = {
  'master',
  'beta',
  'stable',
};

const _supportedDartSdkLiterals = {
  githubSetupMainSdk,
  _pubspecSdkKey,
  'dev',
  'beta',
  'stable',
};

const _allowedMainVersions = {
  'edge', // supported for historical reasons
  travisEdgeSdk,
  githubSetupMainSdk,
};

final _dartSdkLiteralsPretty =
    _supportedDartSdkLiterals.map((e) => '"$e"').join(', ');

final _flutterLiteralsPretty =
    _supportedFlutterSdkLiterals.map((e) => '"$e"').join(', ');

extension PubspecExtension on Pubspec {
  PackageFlavor get flavor =>
      usesFlutter ? PackageFlavor.flutter : PackageFlavor.dart;

  bool get usesFlutter => _dependsOnFlutterSdk || _dependsOnFlutterPackage;

  bool get published => version != null && publishTo != 'none';

  String get pubBadge => published
      ? '[![pub package](https://img.shields.io/pub/v/$name.svg)](https://pub.dev/packages/$name)'
      : '';

  bool get _dependsOnFlutterSdk => environment?.containsKey('flutter') ?? false;

  bool get _dependsOnFlutterPackage => _dependsOnPackage('flutter');

  bool _dependsOnPackage(String package) =>
      (dependencies.containsKey(package)) ||
      (devDependencies.containsKey(package));
}
