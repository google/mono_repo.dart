// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pub_semver/pub_semver.dart';

const travisEdgeSdk = 'be/raw/latest';

const githubSetupMainSdk = 'main'; // this maps to `be/raw/latest`

String errorForSdkConfig(String sdk) {
  try {
    Version.parse(sdk);
    return null;
  } on FormatException {
    if (!_supportedSdkLiterals.contains(sdk)) {
      return 'The value "$sdk" is neither a version string nor one of '
          '$_literalsPretty.';
    }
    return null;
  }
}

void sortNormalizeVerifySdksList(
  List<String> sdks,
  Object Function(String message) errorFactory,
) {
  sdks.sort();
  for (var i = 0; i < sdks.length; i++) {
    var value = sdks[i];
    if (_allowedMainVersions.contains(value)) {
      sdks[i] = value = githubSetupMainSdk;
    }
    final error = errorForSdkConfig(value);
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

const _supportedSdkLiterals = {
  githubSetupMainSdk,
  'dev',
  'beta',
  'stable',
};

const _allowedMainVersions = {
  'edge', // supported for historical reasons
  travisEdgeSdk,
  githubSetupMainSdk,
};

final _literalsPretty = _supportedSdkLiterals.map((e) => '"$e"').join(', ');
