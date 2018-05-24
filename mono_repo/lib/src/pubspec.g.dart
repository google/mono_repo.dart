// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pubspec.dart';

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

Pubspec _$PubspecFromJson(Map json) => $checkedNew(
        'Pubspec',
        json,
        () => new Pubspec(
            $checkedConvert(json, 'name', (v) => v as String),
            $checkedConvert(json, 'version',
                (v) => v == null ? null : _versionFromString(v as String)),
            $checkedConvert(json, 'dependencies', (v) => _getDeps(v as Map)),
            $checkedConvert(
                json, 'dev_dependencies', (v) => _getDeps(v as Map)),
            $checkedConvert(
                json, 'dependency_overrides', (v) => _getDeps(v as Map))),
        fieldKeyMap: const {
          'devDependencies': 'dev_dependencies',
          'dependencyOverrides': 'dependency_overrides'
        });
