// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'commands/github/action_info.dart';
import 'commands/github/overrides.dart';
import 'commands/github/step.dart';
import 'github_config.dart';
import 'package_flavor.dart';

abstract class TaskType implements Comparable<TaskType> {
  static const command = _CommandTask();
  const factory TaskType.githubAction(GitHubActionConfig config) =
      GitHubActionTaskType;

  static const _values = <TaskType>[
    _FormatTask(),
    _AnalyzeTask(),
    _TestTask(),
    command,
    _TestWithCoverageTask(),
  ];

  final String name;

  Iterable<String> get alternates => const Iterable.empty();

  const TaskType._(this.name);

  List<String> commandValue(PackageFlavor flavor, String? args);

  String toJson() => name;

  @override
  String toString() => name;

  @override
  int compareTo(TaskType other) => name.compareTo(other.name);

  Iterable<Step> get beforeAllSteps => const Iterable.empty();

  Iterable<Step> afterEachSteps(String packageDirectory) =>
      const Iterable.empty();

  GitHubActionOverrides? get overrides => null;

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

/// Special [Exception] type used to convey error state that can be caught and
/// re-thrown with more context.
class InvalidTaskConfigException implements Exception {
  final String message;

  const InvalidTaskConfigException(this.message);
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

class _TestWithCoverageTask extends TaskType {
  const _TestWithCoverageTask() : super._('test_with_coverage');

  static int _count = 0;

  @override
  List<String> commandValue(PackageFlavor flavor, String? args) {
    if (flavor == PackageFlavor.flutter) {
      throw const InvalidTaskConfigException(
        'Code coverage tests are not supported with Flutter.',
      );
    }
    return [
      'dart',
      'pub',
      'global',
      'run',
      'coverage:test_with_coverage',
      if (args != null) ...['--', args],
    ];
  }

  @override
  Iterable<Step> get beforeAllSteps => [
        Step.run(
          name: 'Activate package:coverage',
          run: 'dart pub global activate coverage',
        ),
      ];

  @override
  Iterable<Step> afterEachSteps(String packageDirectory) {
    final countString = (_count++).toString().padLeft(2, '0');
    return [
      ActionInfo.coveralls.usage(
        name: 'Upload coverage to Coveralls',
        withContent: {
          // https://docs.github.com/en/actions/security-guides/automatic-token-authentication#using-the-github_token-in-a-workflow
          'github-token': r'${{ secrets.GITHUB_TOKEN }}',
          'path-to-lcov': '$packageDirectory/coverage/lcov.info',
          'flag-name': 'coverage_$countString',
          'parallel': true,
        },
      ),
    ];
  }
}

class GitHubActionTaskType extends TaskType {
  const GitHubActionTaskType(this.overrides) : super._('github_action');

  @override
  final GitHubActionConfig overrides;

  @override
  List<String> commandValue(PackageFlavor flavor, String? args) {
    throw UnimplementedError();
  }
}
