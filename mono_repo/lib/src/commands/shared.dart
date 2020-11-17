// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../version.dart';

const selfValidateJobName = 'mono_repo self validate';

final selfValidateCommands = [
  'pub global activate mono_repo $packageVersion',
  'pub global run mono_repo generate --validate',
];
