import 'package:mono_repo/src/utils.dart';
import 'package:test/test.dart';

final isUserException = new isInstanceOf<UserException>();

Matcher throwsUserExceptionWith(String content) => throwsA(
    allOf(isUserException, (e) => (e as UserException).message == content));

final testConfig1 = r'''
language: dart
dart:
 - dev
 - stable
 - 1.23.0

env:
 - FORCE_TEST_EXIT=true

# Content shell needs these fonts.
addons:
  something: also here for completeness

before_install:
  - ignored for now
  - just here for completeness

dart_task:
 - test: --platform dartium
   install_dartium: true
 - test: --preset travis --total-shards 5 --shard-index 0
   install_dartium: true
 - test: --preset travis --total-shards 5 --shard-index 1
 - test #no args
 - dartanalyzer

matrix:
  exclude:
    - dart: stable
      dart_task: dartanalyzer
  include:
    - dart: dev
      dart_task: dartfmt
''';

final testConfig2 = r'''
language: dart
dart:
 - dev
 - stable
 - 1.23.0

dart_task:
 - test: --platform dartium
 - test: --preset travis --total-shards 5 --shard-index 0
 - test: --preset travis --total-shards 5 --shard-index 1
 - test
 - dartanalyzer

matrix:
  exclude:
    - dart: stable
      dart_task: dartanalyzer
  include:
    - dart: dev
      dart_task: dartfmt
''';
