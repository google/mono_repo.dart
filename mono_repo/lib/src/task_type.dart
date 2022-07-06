// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'commands/github/step.dart';
import 'package_flavor.dart';

abstract class TaskType implements Comparable<TaskType> {
  static const command = _CommandTask();

  static const _values = <TaskType>[
    _FormatTask(),
    _AnalyzeTask(),
    _TestTask(),
    command,
  ];

  final String name;

  Iterable<String> get alternates => const Iterable.empty();

  const TaskType._(this.name);

  factory TaskType.fromJson(String name) =>
      _values.singleWhere((element) => element.name == name);

  List<String> commandValue(PackageFlavor flavor, String? args);

  String toJson() => name;

  @override
  String toString() => name;

  @override
  int compareTo(TaskType other) => name.compareTo(other.name);

  Iterable<Step> get beforeAllSteps => const Iterable.empty();

  Iterable<Step> afterEachSteps(String packageDirectory) =>
      const Iterable.empty();

  static Iterable<String> get allowedTaskNames sync* {
    for (var val in TaskType._values) {
      yield val.name;
      yield* val.alternates;
    }
  }

  static final prettyTaskList =
      TaskType._values.map((t) => '`${t.name}`').join(', ');

  static TaskType taskFromName(String input) => TaskType._values.singleWhere(
        (element) =>
            element.name == input || element.alternates.contains(input),
      );
}

class _FormatTask extends TaskType {
  const _FormatTask() : super._('format');

  @override
  List<String> commandValue(PackageFlavor flavor, String? args) => [
        'dart format',
        (args == null || args == 'sdk')
            ? '--output=none --set-exit-if-changed .'
            : args,
      ];

  @override
  Iterable<String> get alternates => const {'dartfmt'};
}

class _AnalyzeTask extends TaskType {
  const _AnalyzeTask() : super._('analyze');

  @override
  List<String> commandValue(PackageFlavor flavor, String? args) => [
        flavor == PackageFlavor.dart ? 'dart analyze' : 'flutter analyze',
        if (args != null) args
      ];

  @override
  Iterable<String> get alternates => const {'dartanalyzer'};
}

class _TestTask extends TaskType {
  const _TestTask() : super._('test');

  @override
  List<String> commandValue(PackageFlavor flavor, String? args) => [
        flavor == PackageFlavor.dart ? 'dart test' : 'flutter test',
        if (args != null) args,
      ];
}

class _CommandTask extends TaskType {
  const _CommandTask() : super._('command');

  @override
  List<String> commandValue(PackageFlavor flavor, String? args) => [args!];
}
