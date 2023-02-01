## 6.5.0

- Support for generating dependabot configurations.
- Updated `actions/cache`, `actions/checkout`, and `dart-lang/setup-dart` to
  the latest versions.

## 6.4.3

- Updated `actions/cache` and `actions/checkout` to latest versions.
- Require at least Dart >= 2.18.0

## 6.4.2

- Updated `actions/cache`, `subosito/flutter-action`, and
  `actions/checkout` to latest versions.

## 6.4.1

- Updated `actions/cache`, `subosito/flutter-action`, and
  `coverallsapp/github-action` to latest versions.

## 6.4.0

- Added support for `test_with_coverage`.
  Uses `package:coverage` and supports [Coveralls](https://coveralls.io)
  (the default) and [Codecov](https://codecov.com/) to track test code coverage.
- Added support for `pubspec` as an CI target for Dart packages. When used,
  the lower-bound of the support SDK range is used.
- Added `--verbose` flag. Helps when debugging failures.
- Updated `actions/checkout`, `actions/cache`, and `subosito/flutter-action` to
  latest versions.

## 6.3.0

- Update to `subosito/flutter-action@v2.4.0`.
- Require at least Dart >= 2.17.0
- Add the `list` and `readme` commands.
- Update GitHub actions to use hashes instead of version numbers
- Add read-only permissions to actions by default
- Soften detection of a Flutter package. Remove check for `flutter` key in
  `pubspec.yaml`.

## 6.2.2

- Update to `actions/checkout@v3`.

## 6.2.1

- Use `flutter analyze` instead of `dart analyze` for flutter package analyze
  actions. This fixes an issue where analyze jobs could get merged across dart
  and flutter packages, which caused the flutter jobs to fail.

## 6.2.0

- Update to `actions/cache@v3`.

## 6.1.0

- Drop restriction on stages named "test" – only applied to Travis-CI which is
  no longer supported.
- Fix the `pub` command on Windows.
- Update to `subosito/flutter-action@v2.3.0`.
- Update to `actions/checkout@v3.0.0`.

## 6.0.0

- **BREAKING** Replaced the `dart` configuration key within `mono_pkg.yaml` with
  `sdk`. It now covers the Dart _or_ Flutter version to be used for a given
  package - depending on if the package is determined to be a Flutter package by
  the contents of `pubspec.yaml`.
- Added support for Flutter using
  [Flutter action](https://github.com/marketplace/actions/flutter-action). The
  `sdk` value from `mono_pkg.yaml` configures the `channel` setting. Supported
  values are currently "master", "beta", and "stable". (Support for explicit
  versions may be added later.)

## 5.0.5

- Use latest `actions/cache@v2.1.7`.
- Use latest `actions/checkout@v2.4.0`.

## 5.0.4

- Use latest `actions/checkout@v2.3.5`.
- Require Dart SDK >=2.14.0.

## 5.0.3

- Trim GitHub CI cache keys to 512 characters.
- Use latest [dart-lang/setup-dart](https://github.com/dart-lang/setup-dart)
  v1.3.

## 5.0.2

- Use latest [dart-lang/setup-dart](https://github.com/dart-lang/setup-dart)
  v1.2.

## 5.0.1

- Use latest [dart-lang/setup-dart](https://github.com/dart-lang/setup-dart)
  v1.1.

## 5.0.0

- _BREAKING_ Drop support for Travis-CI.
- Change calls from `pub` to `dart pub` within generated scripts.
- Support and encourage up-to-date task names:
    - `analyze` instead of `dartanalyzer`
    - `format` instead of `dartfmt`.

## 4.1.0

- Improve the stability of ordering in Github workflow definitions.
- Use latest `actions/cache@v2.1.6`.
- Migrate to new command pattern supported in Dart 2.10
- `pub` command
    - Now allows any `pub` command and argument combination to be provided.
    - Dropped `--no-precompile` since it is now the default.
    - Now prints a summary of execution progress. Useful for repositories with
      many packages.

## 4.0.0

- Use `FLUTTER_HOME`, if it exists, when using the `pub` command.
- Use `flutter[.bat]` instead of `pub[.bat]` in generated `tool/ci.sh`.
- Migrate code to null safety.
- Require Dart 2.12.
- Use latest `actions/cache@v2.1.5`.
- Use latest `actions/checkout@v2.3.4`.

## 3.4.7

- Use the latest `dart-lang/setup-dart@v1.0`.
- Normalize Dart SDK configurations. Throw on duplicate SDKs. Sort SDKs to
  maintain stable output.

## 3.4.6

- Fix a bug in `3.4.5` with incorrectly configuring the Dart SDK when a semantic
  version is provided.

### GitHub Actions

## 3.4.5

### GitHub Actions

- Move to use [dart-lang/setup-dart](https://github.com/dart-lang/setup-dart) to
  setup the Dart SDK.
    - Remove explicit `dart --version` call. This is handled in the new action.

## 3.4.4

### GitHub Actions

- Always run `pub upgrade|get` steps if checkout succeeds. This ensures that
  tests runs for all packages, even if one package test fails in the same job.

## 3.4.3

### GitHub Actions

- Adds `always() &&` to `if` condition for steps. This makes them run even if
  other steps failed instead of being skipped.

## 3.4.2

### GitHub Actions

- Fix `needs` config to depend on all previous jobs from all stages instead of
  just the previous stage. This fixes issues with skipped stages causing
  subsequent stages to not properly respect certain `if` conditions.

## 3.4.1

### GitHub Actions

- Support `edge` Dart SDKs.

## 3.4.0

- Configuring the target Dart SDK:
    - Allow specifying specific `dev` releases.
    - Allow specifying just `beta`.
- Shorten the generated names for a job if a given component of the name is
  identical for all tasks. Makes it easier to read the names in the GitHub
  Action UI.

### GitHub Actions

- Stop using `tool/ci.sh`. It won't be created when using only GitHub Actions.
- Detect running on Windows on GitHub without setting an extra environment
  variable.
- Separate job commands into a step for each. This makes it easier to see
  exactly what commands were ran on what packages, as well as their individual
  status and output.

## 3.3.0

- Implemented proper support for `stages` in github actions. Jobs will now be
  dependent on previous stages jobs. Conditional stages are also supported in
  the same manner as travis was, see the README.md for more details.

## 3.2.0

- Added support for `on_completion` jobs in github configuration, see the
  `README.md` for details. This allows you to configure things like webhooks
  after failed builds, or publishing after successful builds.

## 3.1.0

- Added support for [GitHub Actions](https://docs.github.com/actions). See
  `README.md` for details.
- Added the `generate` command, since we know support more than one CI provider.
    - **Deprecated** the `travis` command.
- Small improvement to how some strings are emitted in Yaml.

## 3.0.0

- `mono_repo.yaml`:
    - **NEW!** Added support for `pub_action` value. Can be one of `get` or
      `upgrade` (default) to change the package request behavior in each action.
    - **NEW!** Added support for `pretty_ansi` value. The default is `true`. Set
      to `false` to have the generated shell script skip any ANSI formatting.
    - **UPDATED** `self_validate` can now be _either_ `true` or a String value
      that maps to the desired stage where validation should run.
- `travis` command:
    - Many improvements to the generated `tool/travis.sh` file
        - Clearly denote when terminating a job due to incorrect usage or
          configuration.
        - Clearly mark the end of each task and if it succeeded or failed.
        - Print a summary at the end of the tasks for each package to make it
          easier to find and fix failures.
    - **BREAKING** Removed `--use-get` command-line flag. Use `pub_action`
      setting in `mono_repo.yaml` instead.
    - **BREAKING** Removed `--pretty-ansi` command-line flag. Use `pretty_ansi`
      setting in `mono_repo.yaml` instead.
    - Simplified generated configuration for `self_validate`.
      'tool/mono_repo_self_validate.sh' is no longer created or used. When
      upgrading from `v2.5.0`, you can delete this file.

## 2.5.0

- Provide a better error when parsing a poorly formatted Yaml file.
- `mono_repo.yaml`:
    - **NEW!** Added support for `self_validate` boolean value. If `true`,
      creates a shell script and associated task to install the same version of
      `mono_repo` during CI and run `mono_repo travis --validate` to ensure all
      files are up-to-date.
    - Respect the ordering of `stages`, if configured.
    - Allow `stages` values to be just a string – allows defining an explicit
      ordering of stages.
- `mono_pkg.yaml`:
    - Task `command` entry: correctly handle a `List` containing strings.

## 2.4.0

- Adds a `--validate` option to the `travis` command.

    - You can configure this to run from any of your `mono_pkg.yaml` files using
      a command job like this:

      `command: "cd ../ && pub global run mono_repo travis --validate"`.

    - We may make this easier to configure in the future.

- Require Dart SDK `>=2.7.0 <3.0.0`.

## 2.3.0

- Add support for `os` configuration.
    - This generally works in the same way as the `dart` sdk option, except that
      it is not required.
    - The default is to only run on `linux`.
    - Supports a top-level `os` list in `mono_pkg.yaml` files.
    - Supports overriding the `os` per task.

## 2.2.0

- Fix issue where `pub` command failing for one package stops test run for other
  packages grouped into the same Travis task.
- Use `flutter packages` for `pub` command on packages that depend on Flutter.
- Any arguments given to `dartfmt` Travis tasks are used instead of the default
  `-n --set-exit-if-changed .`.
    - To maintain previous behavior, `dartfmt: sdk` is a special case and still
      triggers the default arguments.
- Add `--use-get` optional flag for the `travis` command to use `pub get`
  instead of `pub upgrade` in the generated script.

## 2.1.0

- Require Dart SDK `>=2.2.0 <3.0.0`.

`mono_repo travis`

- Job entries in `.travis.yml` are now ordered. This may cause churn, but will
  create a predictable output going forward.
- While running, print the package when starting each task. Makes it easy to
  scan results when a job has multiple packages.
- Warns if a job specifies a target Dart SDK that is not supported in the
  corresponding `pubspec.yaml`.

`mono_repo pub`

- Added support for all `pub` flags.

## 2.0.0

- _BREAKING_ All commands are recursive by default. To go back to the shallow
  mode, use `--no-recursive`.
- Improve style of the generated `tool/travis.sh` script, including fast-failing
  if the `PKG` variable does not map to an existing directory.
- Require at least Dart 2.1.0.
- The `dart` key is no longer required in `mono_pkg.yaml` if all stages specify
  their own values. A warning is printed if values are provided but not used.
- All output during execution will be sent to STDOUT (instead of STDERR).

## 1.2.2

- Updated dependencies.

## 1.2.1

- Fix issue running with Dart 2.0.

## 1.2.0

- Add `--version` to executable.
- Include the version of the package in generated files.
- Support customizing Travis-CI `branches` in `mono_repo.yaml`.

## 1.1.0

- Improve presubmit command output to list the full command for each task
  instead of the name of the task type only.

## 1.0.0

- Add support for configuring top-level Travis options via `mono_repo.yaml`.

**BREAKING CHANGES**

- The root `mono_config.yaml` file is no longer used to configure which packages
  are configured. Instead, `mono_pkg.yaml` is required to be in each target
  package directory. A package is considered published if it has a value for
  `version` in `pubspec.yaml`.

- The package configuration file is now `mono_pkg.yaml`. If a legacy config file
  – `.mono_repo.yml` – is found, the command is canceled and a warning is
  printed telling the user to rename the file.

- Removed the `init` command.

## 0.3.3

- Support adding custom cache directories in each project.
- Add custom names for travis jobs based on the actual tasks being ran, as well
  as the sdk and subdirectory. The job description portion is configurable with
  the new `description` key for jobs within a stage, for example:

```yaml
stages:
- unit_test:
  - description: "chrome"
    test: -p chrome
```

## 0.3.2+1

- Support Dart 2 stable.

## 0.3.2

- Support dependencies that specify an SDK – common with Flutter.
- Require at least Dart 2.0.0-dev.54.
- `pub` command now runs with inherited standard IO. You now see colors!
- Improved error output with bad configuration.

## 0.3.1

### New Features

- Added support for the `group` task, which accepts a list of tasks using the
  normal format. This can be used to group multiple tasks in a single travis
  job. All tasks will be ran, but if any of them fail then the whole job will
  fail.

  Example usage combining the analyzer/dartfmt tasks:

```yaml
stages:
- analyze_and_format:
  - group:
    - analyze
    - format
```

## 0.3.0

### Breaking Changes

- Sub-package `.travis.yml` files should be replaced with `.mono_repo.yml`
  files, which are a simplified format that supports travis build stages. A
  basic example file might look like this:

```yaml
# List of the sdk versions you support
dart:
- dev
- stable

# Ordered list of all stages you want to run.
stages:
# A single stage, called `analyze_and_format` which runs the analyzer and
# the formatter only.
- analyze_and_format:
  - dartanalyzer: --hints-as-warnings .
  - dartfmt: sdk
    dart:
    - dev # Overrides the top level sdk default
# Assuming everything analyzed correctly, runs a build.
- build:
  - command: "pub run build_runner build"
# And finally run tests, these are custom build_runner tests but the regular
# `test` task is also supported.
- unit_test:
  - command: "pub run build_runner test"
  - command: "pub run build_runner test -- -p chrome"
```

## 0.2.2

- `travis` command

    - Make numbering more consistent and clean when there is more than one task
      with a given name.

    - Print out the full command that executed as part of a task.

    - Support a `List` value for `before_script`.

## 0.2.1

- `travis` command

    - Write ANSI escape sequences in `tool/travis.sh` as pre-escaped ASCII
      literals.

    - Added `--[no-]pretty-ansi` flag to allow ANSI sequences to be optionally
      omitted.

## 0.2.0

- Add `before_script` support to the `travis` command. When that value is set in
  a `travis.yml` file, we will call the script before running any of the tasks
  for that package.

- Add `recursive` global flag. When set, we will walk all sub-directories
  looking for `pubspec.yaml` files.

- Support git dependencies in packages.

- Use `mono_repo.yaml` as the configuration file name, instead of
  `packages.yaml`.

## 0.1.0

- Initial release.
