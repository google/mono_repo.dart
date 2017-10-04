Manage multiple [Dart packages] within a single repository.

### Installation

⚠️ *This will work when mono_repo is published.*
```console
> pub global activate mono_repo
```

### Usage

```
Manage multiple packages in one source repository.

Usage: mono_repo <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  check       Check the state of the repository.
  help        Display help information for mono_repo.
  init        Initialize a new repository.
  presubmit   Run the travis presubmits locally.
  travis      Configure Travis-CI for child packages.

Run "mono_repo help <command>" for more information about a command.
```

[Dart packages]: https://www.dartlang.org/guides/libraries/create-library-packages
