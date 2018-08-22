// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../mono_config.dart';
import '../user_exception.dart';
import '../utils.dart';
import 'mono_repo_command.dart';
import 'travis.dart';

class PresubmitCommand extends MonoRepoCommand {
  @override
  String get name => 'presubmit';

  @override
  String get description => 'Run the travis presubmits locally.';

  PresubmitCommand() {
    argParser.addMultiOption('package',
        help: 'The package(s) to run on, defaults to all packages', abbr: 'p');
    argParser.addMultiOption('task',
        help: 'The task(s) to run, defaults to all tasks', abbr: 't');
    argParser.addOption('sdk',
        help: 'Which sdk to use for match tasks, defaults to current sdk',
        defaultsTo: _currentSdk);
  }

  @override
  Future<Null> run() async {
    var passed = await presubmit(
        packages: argResults['package'] as List<String>,
        tasks: argResults['task'] as List<String>,
        sdkToRun: argResults['sdk'] as String,
        recursive: recursive);

    // Set a bad exit code if it failed.
    if (!passed) exitCode = 1;
  }
}

/// TODO: This doesn't actually match what Travis does, just because
/// you are on a dev release sdk doesn't mean you are on the latest
/// dev release sdk, but its generally a decent approximation.
///
/// This also won't match any exact versions listed in your travis config.
final _currentSdk =
    new Version.parse(Platform.version.split(' ').first).isPreRelease
        ? 'dev'
        : 'stable';

Future<bool> presubmit(
    {Iterable<String> packages,
    Iterable<String> tasks,
    String sdkToRun,
    String rootDirectory,
    bool recursive}) async {
  packages ??= <String>[];
  tasks ??= <String>[];
  sdkToRun ??= _currentSdk;
  Directory tmpDir;

  if (!new File(travisShPath).existsSync()) {
    throw new UserException(
        'No $travisShPath file found, please run the `travis` command first.');
  }

  var configs =
      getMonoConfigs(rootDirectory: rootDirectory, recursive: recursive);
  var commandsToKeys = extractCommands(configs);
  // By default, run on all packages.
  if (packages.isEmpty) packages = configs.keys;
  packages = packages.toList()..sort();

  // By default run all tasks.
  var allKnownTasks = configs.values.fold(new Set<String>(),
      (Set<String> exising, MonoConfig config) {
    return exising
      ..addAll(config.jobs.expand((job) => job.tasks.map((task) => task.name)));
  });
  if (tasks.isEmpty) tasks = allKnownTasks;
  var unrecognizedTasks = tasks.where((task) => !allKnownTasks.contains(task));
  if (unrecognizedTasks.isNotEmpty) {
    throw new UserException(
        'Found ${unrecognizedTasks.length} unrecognized tasks:\n'
        '${unrecognizedTasks.map((task) => '  $task').join('\n')}\n\n'
        'Known tasks are:\n'
        '${allKnownTasks.map((task) => '  $task').join('\n')}');
  }

  // Status of the presubmit.
  var passed = true;
  for (var package in packages) {
    var config = configs[package];
    if (config == null) {
      throw new UserException(
          'Unrecognized package `$package`, known packages are:\n'
          '${configs.keys.map((pkg) => '  $pkg').join('\n')}');
    }

    stderr.writeln(styleBold.wrap(package));
    for (var job in config.jobs) {
      var sdk = job.sdk;
      for (var task in job.tasks) {
        var taskKey = commandsToKeys[task.command];
        // Skip tasks that weren't specified
        if (!tasks.contains(task.name)) continue;

        stderr.write(
            '  Running task ${styleBold.wrap(white.wrap('${task.name}:$sdk'))} ');
        if (sdk != sdkToRun) {
          stderr.writeln(yellow.wrap('(skipped, mismatched sdk)'));
          continue;
        }

        var result = await Process.run(travisShPath, [taskKey],
            environment: {'PKG': package});
        if (result.exitCode == 0) {
          stderr.writeln(green.wrap('(success)'));
        } else {
          tmpDir ??= Directory.systemTemp.createTempSync('mono_repo_');
          var file = new File(
              p.join(tmpDir.path, '${package}_${taskKey}_${job.sdk}.txt'));
          await file.create(recursive: true);
          await file.writeAsString(result.stdout as String);
          stderr.writeln(red.wrap('(failure, ${file.path})'));
          passed = false;
        }
      }
    }
  }
  return passed;
}
