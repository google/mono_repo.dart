// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'coverage_processor.dart';

/// Represents top-level configuration values that are needed by specific
/// jobs or actions.
///
/// Meant to be minimal and expanded on an as-needed basis.
abstract class BasicConfiguration {
  Set<CoverageProcessor> get coverageProcessors;
}
