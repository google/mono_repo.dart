// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class UserException implements Exception {
  final String message;
  final String details;

  UserException(this.message, {this.details});

  @override
  String toString() {
    var msg = 'UserException: $message';

    if (details != null) {
      msg += '\n$details';
    }
    return msg;
  }
}
