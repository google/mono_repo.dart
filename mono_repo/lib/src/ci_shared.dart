import 'dart:async';
import 'dart:io';

import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package_config.dart';
import 'root_config.dart';
import 'version.dart';

/// Object used to flag if code is running in a test.
final testingZoneKey = Object();

bool get _isTesting => Zone.current[testingZoneKey] == true;

// TODO: Eliminate the special logic here. Having a hard-wired version is
// easier for testing.
String createdWith() =>
    _isTesting ? '' : '# Created with package:mono_repo v$packageVersion\n';

String get _pkgVersion => _isTesting ? '1.2.3' : packageVersion;

const selfValidateJobName = 'mono_repo self validate';

final selfValidateCommands = [
  'pub global activate mono_repo $_pkgVersion',
  'pub global run mono_repo generate --validate',
];

class CIJobEntry {
  final CIJob job;
  final List<String> commands;

  CIJobEntry(this.job, this.commands);

  String jobName(List<String> packages) {
    final pkgLabel = packages.length == 1 ? 'PKG' : 'PKGS';

    return 'SDK: ${job.sdk}; $pkgLabel: ${packages.join(', ')}; '
        'TASKS: ${job.name}';
  }
}

void validateRootConfig(RootConfig rootConfig) {
  for (var config in rootConfig) {
    final sdkConstraint = config.pubspec.environment['sdk'];

    if (sdkConstraint == null) {
      continue;
    }

    final disallowedExplicitVersions = config.jobs
        .map((tj) => tj.explicitSdkVersion)
        .where((v) => v != null)
        .toSet()
        .where((v) => !sdkConstraint.allows(v))
        .toList()
          ..sort();

    if (disallowedExplicitVersions.isNotEmpty) {
      final disallowedString =
          disallowedExplicitVersions.map((v) => '`$v`').join(', ');
      print(
        yellow.wrap(
          '  There are jobs defined that are not compatible with '
          'the package SDK constraint ($sdkConstraint): $disallowedString.',
        ),
      );
    }
  }
}

void writeFile(
  String rootDirectory,
  String targetFilePath,
  String fileContent, {
  @required bool isScript,
}) {
  final fullPath = p.join(rootDirectory, targetFilePath);
  final scriptFile = File(fullPath);

  if (!scriptFile.existsSync()) {
    scriptFile.createSync(recursive: true);
    if (isScript) {
      for (var line in scriptLines(targetFilePath)) {
        print(yellow.wrap(line));
      }
    }
  }

  scriptFile.writeAsStringSync(fileContent);
  // TODO: be clever w/ `scriptFile.statSync().mode` to see if it's executable
  print(styleDim.wrap('Wrote `$fullPath`.'));
}

@visibleForTesting
List<String> scriptLines(String scriptPath) => [
      'Make sure to mark `$scriptPath` as executable.',
      '  chmod +x $scriptPath',
      if (Platform.isWindows) ...[
        'It appears you are using Windows, and may not have access to chmod.',
        'If you are using git, the following will emulate the Unix permissions '
            'change:',
        '  git update-index --add --chmod=+x $scriptPath'
      ],
    ];

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

void logPackages(Iterable<PackageConfig> configs) {
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

List<Task> _travisTasks(Iterable<PackageConfig> configs) =>
    configs.expand((config) => config.jobs).expand((job) => job.tasks).toList();
