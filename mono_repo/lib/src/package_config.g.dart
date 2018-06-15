// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PackageConfig _$PackageConfigFromJson(Map json) {
  return $checkedNew('PackageConfig', json, () {
    var val =
        new PackageConfig($checkedConvert(json, 'published', (v) => v as bool));
    return val;
  });
}
