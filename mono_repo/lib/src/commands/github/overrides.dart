abstract class GitHubActionOverrides {
  /// The step's identifier, which can be used to refer to the step and its
  /// outputs in the [ifContent] property of this and other steps.
  String? get id;

  /// The name of the step.
  String? get name;

  /// The shell command to run for this step.
  String? get run;

  /// The GitHub action identifier, e.g. `actions/checkout@v3`.
  String? get uses;

  /// The inputs to the action.
  ///
  /// A map of key-value pairs which are passed to the action's `with`
  /// parameter.
  Map<String, dynamic>? get withContent;

  /// The condition on which to run this action.
  String? get ifContent;

  /// The directory in which to run this action.
  String? get workingDirectory;

  /// The shell override for this action.
  String? get shell;

  /// The environment variables for the step.
  Map<String, String>? get env;

  /// Prevents a job from failing when a step fails.
  bool? get continueOnError;

  /// The number of minutes to allow the step to run.
  int? get timeoutMinutes;
}
