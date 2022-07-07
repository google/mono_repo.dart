// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

enum PackageFlavor {
  dart(pubCommand: 'dart pub', prettyName: 'Dart'),
  flutter(pubCommand: 'flutter pub', prettyName: 'Flutter');

  const PackageFlavor({required this.pubCommand, required this.prettyName});

  final String pubCommand;
  final String prettyName;
}
