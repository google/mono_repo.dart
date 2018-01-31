## 0.2.1

* `travis` command

  * Write ANSI escape sequences in `./tool/travis.sh` as pre-escaped ASCII
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
