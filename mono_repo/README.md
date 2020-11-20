Manage multiple [Dart packages] within a single repository.

## Installation

```console
> pub global activate mono_repo
```

## Running

```console
> pub global run mono_repo
```

Or, once you've [setup your PATH]:

```console
> mono_repo
```

Prints the following help message: 

```
Manage multiple packages in one source repository.

Usage: mono_repo <command> [arguments]

Global options:
-h, --help              Print this usage information.
    --version           Prints the version of mono_repo.
    --[no-]recursive    Whether to recursively walk sub-directories looking for packages.
                        (defaults to on)

Available commands:
  check       Check the state of the repository.
  generate    Generates the CI configuration for child packages.
  presubmit   Run the ci presubmits locally.
  pub         Run `pub get` or `pub upgrade` against all packages.
  travis      (Deprecated, use `generate`) Configure Travis-CI for child packages.

Run "mono_repo help <command>" for more information about a command.
```

## Configuration

### Repo level configuration

To start, you should create a `mono_repo.yaml` file at the root of your repo.

This controls repo wide configuration.

One option you likely want to configure is which CI providers you want to
generate config for. Today both `travis` and `github` are supported, and
can be configured by adding corresponding entries.

You probably also want to enable the `self_validate` option, which will add a
job to ensure that your configuration is up to date.

So, an example config might look like this:

```yaml
# Adds a job that runs `mono_repo generate --validate` to check that everything
# is up to date.
# You can specify the value as just `true` or give a `stage` you'd like this
# job to run in.
self_validate: analyze

# This would enable both CI configurations, you probably only want one though.
travis:
github:
  # Setting just `cron` keeps the defaults for `push` and `pull_request`
  cron: '0 0 * * 0' # “At 00:00 (UTC) on Sunday.”

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

### Adding a package config

To configure a package directory to be included it must contain a
`mono_pkg.yaml` file (along with the normal `pubspec.yaml` file).

You can use an empty `mono_pkg.yaml` file to enable the `check` and `pub`
commands. 

To enable `generate` and `presubmit`, you must populate `mono_pkg.yaml` with
details on how you'd like tests to be run.

#### `mono_pkg.yaml` example

```yaml
# This key is required. It specifies the Dart SDKs your tests will run under
# You can provide one or more value.
# See https://docs.travis-ci.com/user/languages/dart#choosing-dart-versions-to-test-against
# for valid values
dart:
 - dev

stages:
  # Register two jobs to run under the `analyze` stage.
  - analyze:
    - dartanalyzer
    - dartfmt
  - unit_test:
    - test
```

Running `mono_repo generate` in the root directory generates two or more files:
`tool/ci.sh` and a configuration file for each configured ci provider.

Look at these repositories for examples of `mono_repo` usage:

* https://github.com/dart-lang/angular_components
* https://github.com/dart-lang/build
* https://github.com/dart-lang/pub-dev
* https://github.com/dart-lang/source_gen
* https://github.com/dart-lang/webdev
* https://github.com/google/json_serializable.dart

[Dart packages]: https://dart.dev/guides/libraries/create-library-packages
[setup your PATH]: (https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path)
