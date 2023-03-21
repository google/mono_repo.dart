import 'job.dart';
import 'step.dart';

enum ActionInfo implements Comparable<ActionInfo> {
  cache(
    name: 'Cache Pub hosted dependencies',
    repo: 'actions/cache',
    version: '88522ab9f39a2ea568f7027eddc7d8d8bc9d59c8', // v3.3.1
  ),
  checkout(
    name: 'Checkout repository',
    repo: 'actions/checkout',
    version: '24cb9080177205b6e8c946b17badbe402adc938f', // v3.4.0
  ),
  setupDart(
    name: 'Setup Dart SDK',
    repo: 'dart-lang/setup-dart',
    version: 'd6a63dab3335f427404425de0fbfed4686d93c4f', // v1.5.0
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
