// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build_runner/build_runner.dart';
import 'package:json_serializable/json_serializable.dart';

final List<BuildAction> phases = [
  new BuildAction(jsonPartBuilder(header: _dartCopyright), 'mono_repo',
      inputs: const ['lib/src/*'])
];

final _dartCopyright =
    '''// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND
''';
