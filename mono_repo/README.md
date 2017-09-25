```
$ dart --checked ../mono_repo/bin/mono_repo.dart check
    ** Report **

_tests: angular (dev, overridden), angular_compiler (indirect, overridden), angular_test (dev, overridden)
_tests/
       name: _tests
  published: false

angular: angular_compiler (direct, overridden)
angular/
       name: angular
  published: true
    version: 4.0.0-alpha+1

angular_compiler: angular (dev, overridden)
angular_compiler/
       name: angular_compiler
  published: true
    version: 0.1.2

angular_router: angular (direct, overridden)
angular_router/
       name: angular_router
  published: true
    version: 0.1.0

angular_test: angular (direct, overridden), angular_compiler (indirect, overridden)
angular_test/
       name: angular_test
  published: true
    version: 1.0.0-beta+4
```
