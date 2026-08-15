Manage multiple [Dart packages] within a single repository.

[![pub package](https://img.shields.io/pub/v/mono_repo.svg)](https://pub.dev/packages/mono_repo)
[![package publisher](https://img.shields.io/pub/publisher/mono_repo.svg)](https://pub.dev/packages/mono_repo/publisher)
[![Dart CI](https://github.com/google/mono_repo.dart/actions/workflows/dart.yml/badge.svg)](https://github.com/google/mono_repo.dart/actions/workflows/dart.yml)
[![Coverage Status](https://coveralls.io/repos/github/google/mono_repo.dart/badge.svg)](https://coveralls.io/github/google/mono_repo.dart)
[![codecov](https://codecov.io/gh/google/mono_repo.dart/graph/badge.svg?token=KNwhmKCbiV)](https://codecov.io/gh/google/mono_repo.dart)

## Installation

```console
> dart pub global activate mono_repo
```

## Running

```console
> dart pub global run mono_repo
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
    --verbose           Show full stack trace on error. (Useful for debugging.)

Available commands:
  check       Check the state of the repository.
  dart        Runs the `dart` command with the provided arguments across all packages.
  generate    Generates the CI configuration for child packages.
  list        List all packages configured for mono_repo.
  presubmit   Run the CI presubmits locally.
  pub         Runs the `pub` command with the provided arguments across all packages.
  readme      Generate a markdown table of all packages configured for mono_repo.

Run "mono_repo help <command>" for more information about a command.
```

## Configuration

### Repo level configuration

To start, you should create a `mono_repo.yaml` file at the root of your repo.

This controls repo wide configuration.

One option you likely want to configure is which CI providers you want to
generate config for. `github` can be configured by adding a corresponding entry.

You probably also want to enable the `self_validate` option, which will add a
job to ensure that your configuration is up to date.

So, an example config might look like this:

```yaml
# Enabled GitHub actions - https://docs.github.com/actions
# If you have no configuration, you can set the value to `true` or just leave it
# empty.
github:
  # Specify the `on` key to configure triggering events.
  # See https://docs.github.com/actions/reference/workflow-syntax-for-github-actions#on
  # The default values is
  # on:
  #   push:
  #     branches:
  #       - main
  #       - master
  #   pull_request:

  # Setting just `cron` is a shortcut to keep the defaults for `push` and
  # `pull_request` while adding a single `schedule` entry.
  # `on` and `cron` cannot both be set.
  cron: '0 0 * * 0' # “At 00:00 (UTC) on Sunday.”

  # Specify additional environment variables accessible to all jobs
  env:
    FOO: BAR

  # You can group stages into individual workflows
  #
  # Any stages that are omitted here are put in a default workflow
  # named `dart.yml`.
  workflows:
    # The key here is the name of the file - .github/workflows/lint.yml
    lint:
      # This populates `name` in the workflow
      name: Dart Lint CI
      # These are the stages that are populated in the workflow file
      stages:
      - analyze

  # You can add custom github actions configurations to run after completion
  # of all other jobs here. This accepts normal github job config except that
  # the `needs` config is filled in for you, and you aren't allowed to pass it.
  on_completion:
    # Example job that pings a web hook url stored in a github secret with a
    # json payload linking to the failed run.
    - name: "Notify failure"
      runs-on: ubuntu-latest
      # By default this job will only run if all dependent jobs are successful,
      # but we want to run in the failure case for this purpose.
      if: failure()
      steps:
        - run: >
            curl -H "Content-Type: application/json" -X POST -d \
              "{'text':'Build failed! ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}'}" \
              "${CHAT_WEBHOOK_URL}"
          env:
            CHAT_WEBHOOK_URL: ${{ secrets.CHAT_WEBHOOK_URL }}

  # You can customize stage ordering as well as make certain stages be
  # conditional here, this is supported for all CI providers. The `if`
  # condition should use the appropriate syntax for the provider it is being
  # configured for.
  stages:
    - name: cron
      # Only run this stage for scheduled cron jobs
      if: github.event_name == 'schedule'

# Adds a job that runs `mono_repo generate --validate` to check that everything
# is up to date. You can specify the value as just `true` or give a `stage`
# you'd like this job to run in.
self_validate: analyze

# Use this key to merge stages across packages to create fewer jobs
merge_stages:
- analyze

# When using `test_with_coverage`, this setting configures the service that
# results are uploaded to.
# Note: you can configure both options, but this would be unusual.
# Note: you can configure this key with no values, to just generate the files
#   locally. This may be to enable other, custom processing.
coverage_service:
# https://coveralls.io/ - the default
- coveralls
# https://codecov.io/ – the other option
# NOTE: `CODECOV_TOKEN` must be populated in your GitHub actions secrets
- codecov
```

### Adding a package config

To configure a package directory to be included it must contain a
`mono_pkg.yaml` file (along with the normal `pubspec.yaml` file).

You can use an empty `mono_pkg.yaml` file to enable the `check` and `pub`
commands.

To enable `generate` and `presubmit`, you must populate `mono_pkg.yaml` with
details on how you'd like tests to be run.

### Generating `.github/dependabot.yml`
By adding

```yaml
github:
  dependabot: {}
```

To your `mono_repo.yaml` configuration, mono_repo will generate a `.github/dependabot.yml` file that updates all your packages with a default configuration.

Any further configuration can go into the map and will be merged with the
updates of the packages. For example:

```yaml
github:
  dependabot:
    updates:
      - package-ecosystem: "github-actions"
        directory: "/"
        schedule:
          interval: "monthly"
```
#### `mono_pkg.yaml` example

```yaml
# Every entry must be associated with at least one SDK version – corresponding
# to the Dart SDK version or the Flutter framework version, depending on the
# type of package. It can be specified at the top-lever as a single value or
# an array. Alternatively, you can specify the SDK version(s) within each job.
sdk:
 - dev
 # Specific `pubspec` to test the lower-bound SDK defined in pubspec.yaml
 # This is only supported for Dart packages (not Flutter).
 - pubspec

stages:
  # Register two jobs to run under the `analyze` stage.
  - analyze:
    - analyze
    - format
  - unit_test:
    - test
  # Example cron stage which will only run for scheduled jobs (here we run
  # multiple OS configs for extra validation as an example).
  #
  # See the `mono_repo.yaml` example above for where this stage is specially
  # configured.
  - cron:
    - test:
      os:
        - linux
        - windows
```

Running `mono_repo generate` in the root directory generates two or more files:
`tool/ci.sh` and a configuration file for each configured ci provider.

Look at these repositories for examples of `mono_repo` usage:

* https://github.com/dart-lang/build
* https://github.com/dart-lang/pub-dev
* https://github.com/dart-lang/shelf
* https://github.com/dart-lang/source_gen
* https://github.com/dart-lang/test
* https://github.com/dart-lang/webdev
* https://github.com/google/json_serializable.dart

## Mono_repo and Dependabot

Historically, package:mono_repo and Dependabot couldn't be used together -
they both wanted to maintain your GitHub workflow file. We've adopted mono_repo
so that you can now use both it and Dependabot in your repo.

When generating your workflow configuration (`mono_repo generate`) mono_repo
will write out its current default action versions into the workflow file. If
however it sees that the repo has a Dependabot configuration - has a file named
`.github/dependabot.yaml` in the repo - mono_repo will instead parse the
workflow file, read out the current action versions, and use those versions when
re-generating the file. This lets mono_repo manage the overall structure of the
file, while allowing Dependabot to independently move various action versions
forward as necessary.

[Dart packages]: https://dart.dev/guides/libraries/create-library-packages
[setup your PATH]: https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path
