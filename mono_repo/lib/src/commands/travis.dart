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
import 'travis/travis_self_validate.dart';
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
      ..addFlag('validate',
          negatable: false,
          help: 'Validates that the existing travis config is up to date with '
              'the current configuration. Does not write any files.');
  }

  @override
  void run() => generateTravisConfig(
        rootConfig(),
        prettyAnsi: argResults['pretty-ansi'] as bool,
        validateOnly: argResults['validate'] as bool,
      );
}

void generateTravisConfig(
  RootConfig rootConfig, {
  bool prettyAnsi = true,
  bool validateOnly = false,
}) {
  prettyAnsi ??= true;
  validateOnly ??= false;
  final travisConfig = GeneratedTravisConfig.generate(
    rootConfig,
    prettyAnsi: prettyAnsi,
  );
  if (validateOnly) {
    _validateFile(
      rootConfig.rootDirectory,
      travisConfig.travisYml,
      travisFileName,
    );
    _validateFile(
      rootConfig.rootDirectory,
      travisConfig.travisSh,
      travisShPath,
    );
    if (rootConfig.monoConfig.selfValidate) {
      _validateFile(
        rootConfig.rootDirectory,
        travisConfig.selfValidateSh,
        travisSelfValidateScriptPath,
      );
    } else {
      // TODO: print a warning if it exists? Fail? Hrm...
    }
  } else {
    _writeTravisYml(rootConfig.rootDirectory, travisConfig);
    _writeScript(rootConfig.rootDirectory, travisShPath, travisConfig.travisSh);
    if (rootConfig.monoConfig.selfValidate) {
      _writeScript(
        rootConfig.rootDirectory,
        travisSelfValidateScriptPath,
        travisConfig.selfValidateSh,
      );
    } else {
      // TODO: check if self-validate script exists – and tell user they
      // can/should deleted it
    }
  }
}

/// The generated yaml and shell script content for travis.
class GeneratedTravisConfig {
  final String travisYml;
  final String travisSh;
  final String selfValidateSh;

  GeneratedTravisConfig._(this.travisYml, this.travisSh, this.selfValidateSh);

  factory GeneratedTravisConfig.generate(
    RootConfig rootConfig, {
    bool prettyAnsi = true,
  }) {
    prettyAnsi ??= true;
    _logPkgs(rootConfig);

    final commandsToKeys = extractCommands(rootConfig);

    final yml = generateTravisYml(rootConfig, commandsToKeys);

    final sh = generateTravisSh(
      commandsToKeys,
      prettyAnsi,
      rootConfig.monoConfig.pubAction,
    );

    String selfValidateSh;
    if (rootConfig.monoConfig.selfValidate) {
      selfValidateSh = generateSelfValidate();
    }

    return GeneratedTravisConfig._(yml, sh, selfValidateSh);
  }
}

/// Thrown if generated config does not match existing config when running with
/// the `--validate` option.
class TravisConfigOutOfDateException extends UserException {
  TravisConfigOutOfDateException()
      : super(
          'Generated travis config is out of date',
          details: 'Rerun `mono_repo travis` to update generated config',
        );
}

/// Write `.travis.yml`
void _writeTravisYml(String rootDirectory, GeneratedTravisConfig config) {
  final travisYamlPath = p.join(rootDirectory, travisFileName);
  File(travisYamlPath).writeAsStringSync(config.travisYml);
  print(styleDim.wrap('Wrote `$travisYamlPath`.'));
}

/// Checks [expectedPath] versus the content in [expectedContent].
///
/// Throws a [TravisConfigOutOfDateException] if they do not match.
void _validateFile(
  String rootDirectory,
  String expectedContent,
  String expectedPath,
) {
  final shFile = File(p.join(rootDirectory, expectedPath));
  if (!shFile.existsSync() || shFile.readAsStringSync() != expectedContent) {
    throw TravisConfigOutOfDateException();
  }
}

void _writeScript(String rootDirectory, String scriptPath, String content) {
  final fullPath = p.join(rootDirectory, scriptPath);
  final scriptFile = File(fullPath);

  if (!scriptFile.existsSync()) {
    scriptFile.createSync(recursive: true);
    for (var line in [
      'Make sure to mark `$scriptPath` as executable.',
      '  chmod +x $scriptPath',
      if (Platform.isWindows) ...[
        'It appears you are using Windows, and may not have access to chmod.',
        'If you are using git, the following will emulate the Unix permissions '
            'change:',
        '  git update-index --add --chmod=+x $scriptPath'
      ],
    ]) {
      print(yellow.wrap(line));
    }
  }

  scriptFile.writeAsStringSync(content);
  // TODO: be clever w/ `scriptFile.statSync().mode` to see if it's executable
  print(styleDim.wrap('Wrote `$fullPath`.'));
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
