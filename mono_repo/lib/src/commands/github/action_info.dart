import 'job.dart';
import 'step.dart';

enum ActionInfo implements Comparable<ActionInfo> {
  checkout(
    repo: 'actions/checkout',
    version: 'd0651293c4a5a52e711f25b41b05b2212f385d28', // v3
  ),
  cache(
    repo: 'actions/cache',
    version: '4504faf7e9bcf8f3ed0bc863c4e1d21499ab8ef8', // v3
  ),
  setupDart(
    repo: 'dart-lang/setup-dart',
    version: '6a218f2413a3e78e9087f638a238f6b40893203d', // v1.3
  ),
  setupFlutter(
    repo: 'subosito/flutter-action',
    version: '2fb73e25c9488eb544b9b14b2ce00c4c2baf789e', // v2.4.0
  ),
  coveralls(
    repo: 'coverallsapp/github-action',
    version: 'master',
    completionJobFactory: _coverageCompletionJob,
  );

  const ActionInfo({
    required this.repo,
    required this.version,
    this.completionJobFactory,
  });

  final String repo;
  final String version;
  final Job Function()? completionJobFactory;

  Step usage({
    required String name,
    String? id,
    Map<String, dynamic>? withContent,
  }) =>
      _ActionStep(
        info: this,
        id: id,
        name: name,
        withContent: withContent,
      );

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
            'github-token': '\${{ secrets.GITHUB_TOKEN }}',
            'parallel-finished': true
          },
        )
      ],
    );

class _ActionStep extends Step {
  final ActionInfo info;

  _ActionStep({
    required this.info,
    required super.name,
    super.id,
    super.withContent,
  }) : super.uses(
          uses: '${info.repo}@${info.version}',
        );
}

extension StepExtension on Step {
  bool get hasCompletionJob => actionInfo?.completionJobFactory != null;

  ActionInfo? get actionInfo =>
      (this is _ActionStep) ? (this as _ActionStep).info : null;
}
