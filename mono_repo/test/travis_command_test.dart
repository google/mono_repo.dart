import 'package:io/ansi.dart';
import 'package:mono_repo/src/travis_command.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'shared.dart';

void main() {
  test('no package', () async {
    await d.dir('sub_pkg').create();

    expect(() => generateTravisConfig(rootDirectory: d.sandbox),
        throwsUserExceptionWith('No nested packages found.'));
  });

  test('no travis.yml file', () async {
    await d.dir('sub_pkg', [
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
        () => generateTravisConfig(rootDirectory: d.sandbox),
        throwsUserExceptionWith(
            'No entries created. Check your nested `.travis.yml` files.'));
  });

  test('overly complex travis.yml file', () async {
    await d.dir('sub_pkg', [
      d.file('.travis.yml', testConfig1),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    expect(
        () => generateTravisConfig(rootDirectory: d.sandbox),
        throwsUserExceptionWith(
            'Tasks with fancy configuration are not supported. '
            'See `sub_pkg/.travis.yml`.'));
  });

  test('overly complex travis.yml file', () async {
    await d.dir('sub_pkg', [
      d.file('.travis.yml', testConfig2),
      d.file('pubspec.yaml', '''
name: pkg_name
      ''')
    ]).create();

    await overrideAnsiOutput(false, () async {
      await generateTravisConfig(rootDirectory: d.sandbox);
    });

    await d.file('.travis.yml', _config2Yaml).validate();
    await d.file('tool/travis.sh', _config2Shell).validate();
  });
}

final _config2Shell = r'''#!/bin/bash
# Created with https://github.com/dart-lang/mono_repo

# Fast fail the script on failures.
set -e

if [ -z "$PKG" ]; then
  echo -e "PKG environment variable must be set!"
  exit 1
elif [ -z "$TASK" ]; then
  echo -e "TASK environment variable must be set!"
  exit 1
fi

pushd $PKG
pub upgrade

case $TASK in
dartanalyzer) echo
  echo -e "TASK: dartanalyzer"
  dartanalyzer .
  ;;
dartfmt) echo
  echo -e "TASK: dartfmt"
  dartfmt -n --set-exit-if-changed .
  ;;
test) echo
  echo -e "TASK: test"
  pub run test
  ;;
test) echo
  echo -e "TASK: test"
  pub run test --platform dartium
  ;;
test) echo
  echo -e "TASK: test"
  pub run test --preset travis --total-shards 5 --shard-index 0
  ;;
test) echo
  echo -e "TASK: test"
  pub run test --preset travis --total-shards 5 --shard-index 1
  ;;
*) echo -e "Not expecting TASK '${TASK}'. Error!"
  exit 1
  ;;
esac
''';

final _config2Yaml = r'''# Created with https://github.com/dart-lang/mono_repo
language: dart

dart:
  - 1.23.0
  - dev
  - stable

env:
  - PKG=sub_pkg TASK=dartanalyzer
  - PKG=sub_pkg TASK=dartfmt
  - PKG=sub_pkg TASK=test

matrix:
  exclude:
    - dart: stable
      env: PKG=sub_pkg TASK=dartanalyzer
    - dart: 1.23.0
      env: PKG=sub_pkg TASK=dartfmt
    - dart: stable
      env: PKG=sub_pkg TASK=dartfmt

script: ./tool/travis.sh

# Only building master means that we don't run two builds for each pull request.
branches:
  only: [master]

cache:
 directories:
   - $HOME/.pub-cache
''';
