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
    --[no-]recursive    Whether to recursively walk sub-directorys looking for packages.
                        (defaults to on)

Available commands:
  check       Check the state of the repository.
  presubmit   Run the travis presubmits locally.
  pub         Run `pub get` or `pub upgrade` against all packages.
  travis      Configure Travis-CI for child packages.

Run "mono_repo help <command>" for more information about a command.
```

## Configuration

To configure a package directory to be included it must contain a
`mono_pkg.yaml` file (along with the normal `pubspec.yaml` file).

You can use an empty `mono_pkg.yaml` file to enable the `check` and `pub`
commands. 

To enable `travis` and `presubmit`, you must populate `mono_pkg.yaml` with
details on how you'd like tests to be run.

### `mono_pkg.yaml` example

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

Running `mono_repo travis` in the root directory generates two files:
`.travis.yml` and `tool/travis.sh`.

Look at these repositories for examples of `mono_repo` usage:

* https://github.com/dart-lang/angular_components
* https://github.com/dart-lang/build
* https://github.com/dart-lang/json_serializable
* https://github.com/dart-lang/pub-dev
* https://github.com/dart-lang/source_gen
* https://github.com/dart-lang/webdev

[Dart packages]: https://dart.dev/guides/libraries/create-library-packages
[setup your PATH]: (https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path)
