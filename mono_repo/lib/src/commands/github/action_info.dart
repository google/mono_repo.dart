import '../../root_config.dart';
import 'job.dart';
import 'step.dart';

enum ActionInfo implements Comparable<ActionInfo> {
  checkout(
    name: 'Checkout repository',
    repo: 'actions/checkout',
    version: '2541b1294d2704b0964813337f33b291d3f8596b', // v3.0.2
  ),
  cache(
    name: 'Cache Pub hosted dependencies',
    repo: 'actions/cache',
    version: 'ac8075791e805656e71b4ba23325ace9e3421120', // v3.0.9
  ),
  setupDart(
    name: 'Setup Dart SDK',
    repo: 'dart-lang/setup-dart',
    version: '6a218f2413a3e78e9087f638a238f6b40893203d', // v1.3
  ),
  setupFlutter(
    name: 'Setup Flutter SDK',
    repo: 'subosito/flutter-action',
    version: '1e6ee87cb840500837bcd50a667fb28815d8e310', // v2.7.1
  ),

  /// See https://github.com/marketplace/actions/coveralls-github-action
  coveralls(
    name: 'Upload coverage to Coveralls',
    repo: 'coverallsapp/github-action',
    version: 'master',
    completionJobFactory: _coverageCompletionJob,
  ),

  /// See https://github.com/marketplace/actions/codecov
  codecov(
    name: 'Upload coverage to codecov.io',
    repo: 'codecov/codecov-action',
    version: 'd9f34f8cd5cb3b3eb79b3e4b5dae3a16df499a70',
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
            'parallel-finished': true
          },
          versionOverrides: rootConfig.existingActionVersions,
        )
      ],
    );

/// Allows finding [ActionInfo] for a corresponding [Step].
final _actionInfoExpando = Expando<ActionInfo>();

extension StepExtension on Step {
  bool get hasCompletionJob => actionInfo?.completionJobFactory != null;

  ActionInfo? get actionInfo => _actionInfoExpando[this];
}
