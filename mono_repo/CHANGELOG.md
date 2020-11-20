## 3.1.0-beta.4

### GitHub actions

* Allow configuring different workflows for different stages.

    ```yaml
    github:
      # You can group stages into individual workflows  
      workflows:
        # The key here is the name of the file - .github/workflows/lint.yml
        lint:
          # This populates `name` in the workflow
          name: Dart Lint CI
          # These are the stages that are populated in the workflow file
          stages:
          - analyze
      # Any stages that are omitted here are put in a default workflow 
      # named `dart.yml`.
    ```

## 3.1.0-beta.3

### GitHub actions:

* Change default branches to be `['master', 'main']`.
`$default-branch` is for templates.

## 3.1.0-beta.2

### GitHub actions

* **BREAK** from previous betas: `ci` is no longer supported as a top-level
  value in `mono_repo.yaml`. Instead, the top-level keys `travis` and `github`
  are used. If they exist (even if empty) they enable that CI target.
* Added `github` top-level key.
  * Configure the `on` value to control what triggers the generated defined
    workflow.
  * A short-cut value `cron` is also supported – it can be a String that
    adds a single scheduled job to the default `on` value.
* Support `stable` as a valid Dart SDK label.
* Use `[$default-branch]` instead of `[master]`.
* Prints the Dart SDK version after installation.
* Now supports `self_validate`.

## 3.1.0-beta.1

* Fix self-validate logic.

## 3.1.0-beta

* Adds support for Github Actions configuration.
  * There is a new `ci` key in the `mono_repo.yaml` file which accepts a list
    of providers to generate for, see the README.md for details.
  * There is also a new command `generate` which replaces the `travis` command.
* Deprecated the `travis` command.
* Small improvement to how some strings are emitted in Yaml.

## 3.0.0

* `mono_repo.yaml`:
  * **NEW!** Added support for `pub_action` value.
    Can be one of `get` or `upgrade` (default) to change the package request
    behavior in each action.
  * **NEW!** Added support for `pretty_ansi` value.
    The default is `true`. Set to `false` to have the generated shell script
    skip any ANSI formatting.
  * **UPDATED** `self_validate` can now be _either_ `true` or a String value
    that maps to the desired stage where validation should run.
* `travis` command:
  * Many improvements to the generated `tool/travis.sh` file
    * Clearly denote when terminating a job due to incorrect usage or 
      configuration.
    * Clearly mark the end of each task and if it succeeded or failed.
    * Print a summary at the end of the tasks for each package to make it easier
      to find and fix failures.
  * **BREAKING** Removed `--use-get` command-line flag. Use `pub_action`
    setting in `mono_repo.yaml` instead.
  * **BREAKING** Removed `--pretty-ansi` command-line flag. Use `pretty_ansi`
    setting in `mono_repo.yaml` instead.
  * Simplified generated configuration for `self_validate`.
    'tool/mono_repo_self_validate.sh' is no longer created or used.
    When upgrading from `v2.5.0`, you can delete this file.

## 2.5.0

* Provide a better error when parsing a poorly formatted Yaml file.
* `mono_repo.yaml`:
  * **NEW!** Added support for `self_validate` boolean value.
    If `true`, creates a shell script and associated task to install the same
    version of `mono_repo` during CI and run `mono_repo travis --validate` to
    ensure all files are up-to-date.
  * Respect the ordering of `stages`, if configured.
  * Allow `stages` values to be just a string – allows defining an explicit
    ordering of stages. 
* `mono_pkg.yaml`:
  * Task `command` entry: correctly handle a `List` containing strings.

## 2.4.0

- Adds a `--validate` option to the `travis` command.
  - You can configure this to run from any of your `mono_pkg.yaml` files using
    a command job like this:
    
    `command: "cd ../ && pub global run mono_repo travis --validate"`.
  - We may make this easier to configure in the future.
- Require Dart SDK `>=2.7.0 <3.0.0`.

## 2.3.0

- Add support for `os` configuration.
  - This generally works in the same way as the `dart` sdk option, except
    that it is not required.
  - The default is to only run on `linux`.
  - Supports a top-level `os` list in `mono_pkg.yaml` files.
  - Supports overriding the `os` per task.

## 2.2.0

- Fix issue where `pub` command failing for one package stops test run for
  other packages grouped into the same Travis task.
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
- While running, print the package when starting each task.
  Makes it easy to scan results when a job has multiple packages.
- Warns if a job specifies a target Dart SDK that is not supported in the
  corresponding `pubspec.yaml`.

`mono_repo pub`
- Added support for all `pub` flags.

## 2.0.0

* *BREAKING* All commands are recursive by default. To go back to the shallow
  mode, use `--no-recursive`.
* Improve style of the generated `tool/travis.sh` script, including fast-failing
  if the `PKG` variable does not map to an existing directory.
* Require at least Dart 2.1.0.
* The `dart` key is no longer required in `mono_pkg.yaml` if all stages specify
  their own values. A warning is printed if values are provided but not used.
* All output during execution will be sent to STDOUT (instead of STDERR).

## 1.2.2

* Updated dependencies.

## 1.2.1

* Fix issue running with Dart 2.0.

## 1.2.0

* Add `--version` to executable.
* Include the version of the package in generated files.
* Support customizing Travis-CI `branches` in `mono_repo.yaml`.

## 1.1.0

* Improve presubmit command output to list the full command for each task
  instead of the name of the task type only.

## 1.0.0

* Add support for configuring top-level Travis options via `mono_repo.yaml`.

**BREAKING CHANGES**

* The root `mono_config.yaml` file is no longer used to configure which packages
  are configured. Instead, `mono_pkg.yaml` is required to be in each target
  package directory. A package is considered published if it has a value for
  `version` in `pubspec.yaml`.

* The package configuration file is now `mono_pkg.yaml`. If a legacy config file
  – `.mono_repo.yml` – is found, the command is canceled and a warning is
  printed telling the user to rename the file.

* Removed the `init` command.

## 0.3.3

* Support adding custom cache directories in each project.
* Add custom names for travis jobs based on the actual tasks being ran, as well
  as the sdk and subdirectory. The job description portion is configurable with
  the new `description` key for jobs within a stage, for example:

```yaml
stages:
  - unit_test:
    - description: "chrome"
      test: -p chrome
```

## 0.3.2+1

* Support Dart 2 stable.

## 0.3.2

* Support dependencies that specify an SDK – common with Flutter.
* Require at least Dart 2.0.0-dev.54.
* `pub` command now runs with inherited standard IO. You now see colors!
* Improved error output with bad configuration.

## 0.3.1

### New Features

* Added support for the `group` task, which accepts a list of tasks using the
  normal format. This can be used to group multiple tasks in a single travis
  job. All tasks will be ran, but if any of them fail then the whole job will
  fail.

  Example usage combining the analyzer/dartfmt tasks:

```yaml
stages:
  - analyze_and_format:
    - group:
        - dartanalyzer
        - dartfmt
```

## 0.3.0

### Breaking Changes

* Sub-package `.travis.yml` files should be replaced with `.mono_repo.yml`
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

* `travis` command

  * Make numbering more consistent and clean when there is more than one task
    with a given name.

  * Print out the full command that executed as part of a task.

  * Support a `List` value for `before_script`.

## 0.2.1

* `travis` command

  * Write ANSI escape sequences in `tool/travis.sh` as pre-escaped ASCII
    literals.

  * Added `--[no-]pretty-ansi` flag to allow ANSI sequences to be optionally
    omitted.

## 0.2.0

* Add `before_script` support to the `travis` command. When that value is set in
  a `travis.yml` file, we will call the script before running any of the tasks
  for that package.

* Add `recursive` global flag. When set, we will walk all sub-directories
  looking for `pubspec.yaml` files.

* Support git dependencies in packages.

* Use `mono_repo.yaml` as the configuration file name, instead of
  `packages.yaml`.

## 0.1.0

* Initial release.
