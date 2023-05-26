import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart' hide stronglyConnectedComponents;
import 'package:graphs/graphs.dart';
import 'package:io/ansi.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'mono_config.dart';
import 'package_config.dart';
import 'root_config.dart';
import 'user_exception.dart';
import 'version.dart';

/// Run [function] (using the optional [zoneSpec] while override the version
/// to `1.2.3` and forcing off ANSI color output.
T testGenerate<T>(T Function() function, {ZoneSpecification? zoneSpec}) =>
    runZoned(
      () => overrideAnsiOutput(false, function),
      zoneValues: {_testingZoneKey: true},
      zoneSpecification: zoneSpec,
    );

/// Object used to flag if code is running in a test.
final _testingZoneKey = Object();

bool get _isTesting => Zone.current[_testingZoneKey] == true;

String get createdWith => '# Created with package:mono_repo v$_pkgVersion';

String get _pkgVersion => _isTesting ? '1.2.3' : packageVersion;

const calculateChangesJobName = 'Calculating affected packages';
const selfValidateJobName = 'mono_repo self validate';

final selfValidateCommands = [
  'dart pub global activate mono_repo $_pkgVersion',
  'dart pub global run mono_repo generate --validate',
];

class CIJobEntry {
  final CIJob job;
  final List<String> commands;

  CIJobEntry(this.job, this.commands);

  String jobName(
    List<String> packages, {
    required bool includeOs,
    required bool includeSdk,
    required bool includePackage,
    required bool includeStage,
  }) {
    final packageLabel = packages.length == 1 ? 'PKG' : 'PKGS';
    final sections = [
      if (includeStage) job.stageName,
      if (!includeOs) job.os,
      if (!includeSdk) '${job.flavor.prettyName} ${job.sdk}',
      if (!includePackage) '$packageLabel: ${packages.join(', ')}',
      job.name,
    ];

    return sections.join('; ');
  }
}

/// Group jobs by all of the values that would allow them to merge
Map<String, List<CIJobEntry>> groupCIJobEntries(List<CIJobEntry> jobEntries) =>
    groupBy<CIJobEntry, String>(
      jobEntries,
      (e) => [
        ...e.job.groupByKeys,
        e.commands,
      ].join(':::'),
    );

void validateRootConfig(RootConfig rootConfig) {
  for (var config in rootConfig) {
    final sdkConstraint = config.pubspec.environment?['sdk'];

    if (sdkConstraint == null) {
      continue;
    }

    final disallowedExplicitVersions = config.jobs
        .map((tj) => tj.explicitSdkVersion)
        .whereType<Version>()
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
  required bool isScript,
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
  final taskNames = tasksToConfigure.map((task) => task.type).toSet();

  for (var taskName in taskNames) {
    final commands = tasksToConfigure
        .where((task) => task.type == taskName)
        .map((task) => task.command)
        .toSet();

    if (commands.length == 1) {
      commandsToKeys[commands.single] = taskName.name;
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
    final sdks = pkg.sdks;
    if (sdks != null && sdks.isNotEmpty && !pkg.dartSdkConfigUsed) {
      print(
        yellow.wrap(
          '  `dart` values (${sdks.join(', ')}) are not used '
          'and can be removed.',
        ),
      );
    }
    if (!pkg.osConfigUsed && pkg.oses.isNotEmpty) {
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
List<String> calculateOrderedStages(
  RootConfig rootConfig,
  Map<String, ConditionalStage> conditionalStages,
) {
  // Convert the configs to a graph so we can run strongly connected components.
  final edges = <String, Set<String>>{};

  String? previous;
  for (var stage in conditionalStages.keys) {
    edges.putIfAbsent(stage, () => <String>{});
    if (previous != null) {
      edges[previous]!.add(stage);
    }
    previous = stage;
  }

  final rootMentionedStages = <String>{
    ...conditionalStages.keys,
    ...rootConfig.monoConfig.mergeStages,
  };

  for (var config in rootConfig) {
    String? previous;
    for (var stage in config.stageNames) {
      rootMentionedStages.remove(stage);
      edges.putIfAbsent(stage, () => <String>{});
      if (previous != null) {
        edges[previous]!.add(stage);
      }
      previous = stage;
    }
  }

  if (rootMentionedStages.isNotEmpty) {
    final items = rootMentionedStages.map((e) => '`$e`').join(', ');

    throw UserException(
      'Error parsing mono_repo.yaml',
      details: 'One or more stage was referenced in `mono_repo.yaml` that do '
          'not exist in any `$monoPkgFileName` files: $items.',
    );
  }

  final List<String> components;
  try {
    // Build up a map of the keys to their index in `edges.keys`, which we use
    // as a secondary sort. This is an intuitive secondary sort order as it
    // follows the order given in configuration files.
    final keys = edges.keys.toList();
    final edgeIndexes = {
      for (var i = 0; i < keys.length; i++) keys[i]: i,
    };

    // Orders by dependencies first, and detect cycles (which aren't allowed).
    // Our edges here are actually reverse edges already, so a topological sort
    // gives us the right thing.
    components = topologicalSort(
      keys,
      (n) => edges[n]!,
      secondarySort: (a, b) => edgeIndexes[b]!.compareTo(edgeIndexes[a]!),
    );
  } on CycleException<String> catch (e) {
    final items = e.cycle.map((e) => '`$e`').join(', ');
    throw UserException(
      'Not all packages agree on `stages` ordering, found '
      'a cycle between the following stages: $items.',
    );
  }

  if (rootConfig.monoConfig.selfValidateStage != null &&
      !components.contains(rootConfig.monoConfig.selfValidateStage)) {
    components.insert(0, rootConfig.monoConfig.selfValidateStage!);
  }

  return components;
}

List<Task> _travisTasks(Iterable<PackageConfig> configs) =>
    configs.expand((config) => config.jobs).expand((job) => job.tasks).toList();
