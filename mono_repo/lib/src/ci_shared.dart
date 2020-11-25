import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart' hide stronglyConnectedComponents;
import 'package:graphs/graphs.dart';
import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'mono_config.dart';
import 'package_config.dart';
import 'root_config.dart';
import 'user_exception.dart';
import 'version.dart';

/// Run [function] (using the optional [zoneSpec] while override the version
/// to `1.2.3` and forcing off ANSI color output.
T testGenerate<T>(T Function() function, {ZoneSpecification zoneSpec}) =>
    Zone.current.fork(
      zoneValues: {_testingZoneKey: true},
      specification: zoneSpec,
    ).run(
      () => overrideAnsiOutput(false, function),
    );

/// Object used to flag if code is running in a test.
final _testingZoneKey = Object();

bool get _isTesting => Zone.current[_testingZoneKey] == true;

String get createdWith => '# Created with package:mono_repo v$_pkgVersion';

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

/// Group jobs by all of the values that would allow them to merge
Map<String, List<CIJobEntry>> groupCIJobEntries(List<CIJobEntry> jobEntries) =>
    groupBy<CIJobEntry, String>(
        jobEntries,
        (e) => [
              e.job.os,
              e.job.stageName,
              e.job.sdk,
              // TODO: sort these? Would merge jobs with different orders
              e.commands,
            ].join(':::'));

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

/// Calculates the global stages ordering, and throws a [UserException] if it
/// detects any cycles.
///
/// Ordering is determined by the order that stages appear in `mono_pkg.yaml`
/// files, as well as `mono_repo.yaml` files if configured as conditional
/// stages.
///
/// The [conditionalStages] are CI specific, as they use CI specific expression
/// syntax.
List<Object /*ConditionalStage|String*/ > calculateOrderedStages(
    RootConfig rootConfig, Map<String, ConditionalStage> conditionalStages) {
  // Convert the configs to a graph so we can run strongly connected components.
  final edges = <String, Set<String>>{};

  String previous;
  for (var stage in conditionalStages.keys) {
    edges.putIfAbsent(stage, () => <String>{});
    if (previous != null) {
      edges[previous].add(stage);
    }
    previous = stage;
  }

  final rootMentionedStages = <String>{
    ...conditionalStages.keys,
    ...rootConfig.monoConfig.mergeStages,
  };

  for (var config in rootConfig) {
    String previous;
    for (var stage in config.stageNames) {
      rootMentionedStages.remove(stage);
      edges.putIfAbsent(stage, () => <String>{});
      if (previous != null) {
        edges[previous].add(stage);
      }
      previous = stage;
    }
  }

  if (rootMentionedStages.isNotEmpty) {
    final items = rootMentionedStages.map((e) => '`$e`').join(', ');

    throw UserException(
      'Error parsing mono_repo.yaml',
      details: 'One or more stage was referenced in `mono_repo.yaml` that do '
          'not exist in any `mono_pkg.yaml` files: $items.',
    );
  }

  // Running strongly connected components lets us detect cycles (which aren't
  // allowed), and gives us the reverse order of what we ultimately want.
  final components = stronglyConnectedComponents(edges.keys, (n) => edges[n]);
  for (var component in components) {
    if (component.length > 1) {
      final items = component.map((e) => '`$e`').join(', ');
      throw UserException(
        'Not all packages agree on `stages` ordering, found '
        'a cycle between the following stages: $items.',
      );
    }
  }

  final orderedStages = components
      .map((c) {
        final stageName = c.first;

        final matchingStage = conditionalStages[stageName];

        return matchingStage?.toJson() ?? stageName;
      })
      .toList()
      .reversed
      .toList();

  if (rootConfig.monoConfig.selfValidateStage != null &&
      !orderedStages.contains(rootConfig.monoConfig.selfValidateStage)) {
    orderedStages.insert(0, rootConfig.monoConfig.selfValidateStage);
  }

  return orderedStages;
}

List<Task> _travisTasks(Iterable<PackageConfig> configs) =>
    configs.expand((config) => config.jobs).expand((job) => job.tasks).toList();
