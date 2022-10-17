import 'job.dart';
import 'step.dart';

enum ActionInfo implements Comparable<ActionInfo> {
  checkout(
    name: 'Checkout repository',
    repo: 'actions/checkout',
    version: '93ea575cb5d8a053eaa0ac8fa3b40d7e05a33cc8', // v3.1.0
  ),
  cache(
    name: 'Cache Pub hosted dependencies',
    repo: 'actions/cache',
    version: '9b0c1fce7a93df8e3bb8926b0d6e9d89e92f20a7', // v3.0.11
  ),
  setupDart(
    name: 'Setup Dart SDK',
    repo: 'dart-lang/setup-dart',
    version: '6a218f2413a3e78e9087f638a238f6b40893203d', // v1.3
  ),
  setupFlutter(
    name: 'Setup Flutter SDK',
    repo: 'subosito/flutter-action',
    version: 'dbf1fa04f4d2e52c33185153d06cdb5443aa189d', // v2.8.0
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
    version: 'main',
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
  final Job Function()? completionJobFactory;

  Step usage({
    String? name,
    String? id,
    Map<String, dynamic>? withContent,
  }) {
    name ??= this.name;
    final step = Step.uses(
      uses: '$repo@$version',
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

Job _coverageCompletionJob() => Job(
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
        )
      ],
    );

/// Allows finding [ActionInfo] for a corresponding [Step].
final _actionInfoExpando = Expando<ActionInfo>();

extension StepExtension on Step {
  bool get hasCompletionJob => actionInfo?.completionJobFactory != null;

  ActionInfo? get actionInfo => _actionInfoExpando[this];
}
