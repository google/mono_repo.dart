// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;

import '../package_config.dart';
import '../root_config.dart';
import '../user_exception.dart';
import 'mono_repo_command.dart';
import 'travis/travis_shell.dart';
import 'travis/travis_yaml.dart';

class TravisCommand extends MonoRepoCommand {
  @override
  String get name => 'travis';

  @override
  String get description => 'Configure Travis-CI for child packages.';

  TravisCommand() : super() {
    argParser
      ..addFlag(
        'pretty-ansi',
        abbr: 'p',
        defaultsTo: true,
        help:
            'If the generated `$travisShPath` file should include ANSI escapes '
            'to improve output readability.',
      )
      ..addFlag('use-get',
          negatable: false,
          help:
              'If the generated `$travisShPath` file should use `pub get` for '
              'dependencies instead of `pub upgrade`.')
      ..addFlag('validate',
          negatable: false,
          help: 'Validates that the existing travis config is up to date with '
              'the current configuration. Does not write any files.');
  }

  @override
  void run() => generateTravisConfig(
        rootConfig(),
        prettyAnsi: argResults['pretty-ansi'] as bool,
        useGet: argResults['use-get'] as bool,
        validateOnly: argResults['validate'] as bool,
      );
}

void generateTravisConfig(
  RootConfig configs, {
  bool prettyAnsi = true,
  bool useGet = false,
  bool validateOnly = false,
}) {
  prettyAnsi ??= true;
  useGet ??= false;
  validateOnly ??= false;
  final travisConfig = GeneratedTravisConfig.generate(
    configs,
    prettyAnsi: prettyAnsi,
    useGet: useGet,
  );
  if (validateOnly) {
    _checkTravisYml(configs.rootDirectory, travisConfig);
    _checkTravisScript(configs.rootDirectory, travisConfig);
  } else {
    _writeTravisYml(configs.rootDirectory, travisConfig);
    _writeTravisScript(configs.rootDirectory, travisConfig);
  }
}

/// Check existing `.travis.yml` versus the content in [config].
///
/// Throws a [TravisConfigOutOfDateException] if they do not match.
void _checkTravisYml(String rootDirectory, GeneratedTravisConfig config) {
  final yamlFile = File(p.join(rootDirectory, travisFileName));
  if (!yamlFile.existsSync() ||
      yamlFile.readAsStringSync() != config.travisYml) {
    throw TravisConfigOutOfDateException();
  }
}

/// The generated yaml and shell script content for travis.
class GeneratedTravisConfig {
  final String travisYml;
  final String travisSh;

  GeneratedTravisConfig._(this.travisYml, this.travisSh);

  factory GeneratedTravisConfig.generate(
    RootConfig configs, {
    bool prettyAnsi = true,
    bool useGet = false,
  }) {
    prettyAnsi ??= true;
    useGet ??= false;

    _logPkgs(configs);

    final commandsToKeys = extractCommands(configs);

    final yml = generateTravisYml(configs, commandsToKeys);

    final sh = generateTravisSh(
      calculateTaskEntries(commandsToKeys, prettyAnsi),
      prettyAnsi,
      useGet ? 'get' : 'upgrade',
    );

    return GeneratedTravisConfig._(yml, sh);
  }
}

/// Thrown if generated config does not match existing config when running with
/// the `--validate` option.
class TravisConfigOutOfDateException extends UserException {
  TravisConfigOutOfDateException()
      : super('Generated travis config is out of date',
            details: 'Rerun `mono_repo travis` to update generated config');
}

/// Write `.travis.yml`
void _writeTravisYml(String rootDirectory, GeneratedTravisConfig config) {
  final travisYamlPath = p.join(rootDirectory, travisFileName);
  File(travisYamlPath).writeAsStringSync(config.travisYml);
  print(styleDim.wrap('Wrote `$travisYamlPath`.'));
}

/// Checks the existing `tool/travis.sh` versus the content in [config].
///
/// Throws a [TravisConfigOutOfDateException] if they do not match.
void _checkTravisScript(String rootDirectory, GeneratedTravisConfig config) {
  final shFile = File(p.join(rootDirectory, travisShPath));
  if (!shFile.existsSync() || shFile.readAsStringSync() != config.travisSh) {
    throw TravisConfigOutOfDateException();
  }
}

/// Write `tool/travis.sh`
void _writeTravisScript(String rootDirectory, GeneratedTravisConfig config) {
  final travisScriptPath = p.join(rootDirectory, travisShPath);
  final travisScript = File(travisScriptPath);

  if (!travisScript.existsSync()) {
    travisScript.createSync(recursive: true);
    print(yellow.wrap('Make sure to mark `$travisShPath` as executable.'));
    print(yellow.wrap('  chmod +x $travisShPath'));
    if (Platform.isWindows) {
      print(
        yellow.wrap(
          'It appears you are using Windows, and may not have access to chmod.',
        ),
      );
      print(
        yellow.wrap(
          'If you are using git, the following will emulate the Unix '
          'permissions change:',
        ),
      );
      print(yellow.wrap('  git update-index --add --chmod=+x $travisShPath'));
    }
  }

  travisScript.writeAsStringSync(config.travisSh);
  // TODO: be clever w/ `travisScript.statSync().mode` to see if it's executable
  print(styleDim.wrap('Wrote `$travisScriptPath`.'));
}

/// Gives a map of command to unique task key for all [configs].
Map<String, String> extractCommands(Iterable<PackageConfig> configs) {
  final commandsToKeys = <String, String>{};

  final tasksToConfigure = _travisTasks(configs);
  final taskNames = tasksToConfigure.map((task) => task.name).toSet();

  for (var taskName in taskNames) {
    final commands = tasksToConfigure
        .where((task) => task.name == taskName)
        .map((task) => task.command)
        .toSet();

    if (commands.length == 1) {
      commandsToKeys[commands.single] = taskName;
      continue;
    }

    // TODO: could likely use some clever `log` math here
    final paddingSize = (commands.length - 1).toString().length;

    var count = 0;
    for (var command in commands) {
      commandsToKeys[command] =
          '${taskName}_${count.toString().padLeft(paddingSize, '0')}';
      count++;
    }
  }

  return commandsToKeys;
}

List<Task> _travisTasks(Iterable<PackageConfig> configs) =>
    configs.expand((config) => config.jobs).expand((job) => job.tasks).toList();

void _logPkgs(Iterable<PackageConfig> configs) {
  for (var pkg in configs) {
    print(styleBold.wrap('package:${pkg.relativePath}'));
    if (pkg.sdks != null && !pkg.dartSdkConfigUsed) {
      print(
        yellow.wrap(
          '  `dart` values (${pkg.sdks.join(', ')}) are not used '
          'and can be removed.',
        ),
      );
    }
    if (pkg.oses != null && !pkg.osConfigUsed) {
      print(
        yellow.wrap(
          '  `os` values (${pkg.oses.join(', ')}) are not used '
          'and can be removed.',
        ),
      );
    }
  }
}
