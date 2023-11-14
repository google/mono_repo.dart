import '../../root_config.dart';
import 'action_versions.dart';
import 'job.dart';
import 'step.dart';

enum ActionInfo implements Comparable<ActionInfo> {
  cache(
    name: 'Cache Pub hosted dependencies',
    repo: 'actions/cache',
    version: actionsCacheVersion,
  ),
  checkout(
    name: 'Checkout repository',
    repo: 'actions/checkout',
    version: actionsCheckoutVersion,
  ),
  setupDart(
    name: 'Setup Dart SDK',
    repo: 'dart-lang/setup-dart',
    version: dartLangSetupDartVersion,
  ),
  setupFlutter(
    name: 'Setup Flutter SDK',
    repo: 'subosito/flutter-action',
    version: subositoFlutterActionVersion,
  ),

  /// See https://github.com/marketplace/actions/coveralls-github-action
  coveralls(
    name: 'Upload coverage to Coveralls',
    repo: 'coverallsapp/github-action',
    version: coverallsappGithubActionVersion,
    completionJobFactory: _coverageCompletionJob,
  ),

  /// See https://github.com/marketplace/actions/codecov
  codecov(
    name: 'Upload coverage to codecov.io',
    repo: 'codecov/codecov-action',
    version: codecovCodecovActionVersion,
  ),

  /// See https://github.com/marketplace/actions/paths-changes-filter
  pathsFilter(
    name: 'Produce variables based on which packages are affected',
    repo: 'dorny/paths-filter',
    version: dornyPathsFilterVersion,
  );

  const ActionInfo({
    required this.repo,
    required this.version,
    required this.name,
    this.completionJobFactory,
  });

  final String repo;
  final String version;
  final String name;
  final Job Function(RootConfig rootConfig)? completionJobFactory;

  Step usage({
    String? name,
    String? id,
    Map<String, dynamic>? withContent,
    Map<String, String>? versionOverrides,
  }) {
    name ??= this.name;
    final useVersion =
        (versionOverrides == null ? null : versionOverrides[repo]) ?? version;
    final step = Step.uses(
      uses: '$repo@$useVersion',
      id: id,
      name: name,
      withContent: withContent,
    );
    // store away the action info for later use.
    _actionInfoExpando[step] = this;
    return step;
  }

  @override
  int compareTo(ActionInfo other) => index.compareTo(other.index);
}

Job _coverageCompletionJob(RootConfig rootConfig) => Job(
      name: 'Mark Coveralls job finished',
      runsOn: 'ubuntu-latest',
      steps: [
        ActionInfo.coveralls.usage(
          name: 'Mark Coveralls job finished',
          withContent: {
            // https://docs.github.com/en/actions/security-guides/automatic-token-authentication#using-the-github_token-in-a-workflow
            'github-token': r'${{ secrets.GITHUB_TOKEN }}',
            'parallel-finished': true,
          },
          versionOverrides: rootConfig.existingActionVersions,
        ),
      ],
    );

/// Allows finding [ActionInfo] for a corresponding [Step].
final _actionInfoExpando = Expando<ActionInfo>();

extension StepExtension on Step {
  bool get hasCompletionJob => actionInfo?.completionJobFactory != null;

  ActionInfo? get actionInfo => _actionInfoExpando[this];
}
