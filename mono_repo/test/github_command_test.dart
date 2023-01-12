// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mono_repo/src/github_config.dart';
import 'package:mono_repo/src/yaml.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  glyph.ascii = false;

  test(
    'only supported keys',
    () => _testBadConfigWithYamlException(
      {
        'github': {'not_supported': 5}
      },
      r'''
line 2, column 3 of mono_repo.yaml: Unrecognized keys: [not_supported]; supported keys: [env, on, on_completion, dependabot, cron, stages, workflows]
  ╷
2 │   not_supported: 5
  │   ^^^^^^^^^^^^^
  ╵''',
    ),
  );

  test(
    '"on" must be a Map',
    () => _testBadConfigWithYamlException(
      {
        'github': {'on': 'not a map'}
      },
      r'''
line 2, column 7 of mono_repo.yaml: Unsupported value for "on". type 'String' is not a subtype of type 'Map<dynamic, dynamic>?' in type cast
  ╷
2 │   on: not a map
  │       ^^^^^^^^^
  ╵''',
    ),
  );

  test(
    'no cron with on',
    () => _testBadConfigWithYamlException(
      {
        'github': {'cron': 'some value', 'on': {}}
      },
      r'''
line 2, column 9 of mono_repo.yaml: Unsupported value for "cron". Cannot set `cron` if `on` has a value.
  ╷
2 │   cron: some value
  │         ^^^^^^^^^^
  ╵''',
    ),
  );

  test(
    'env must be a map',
    () => _testBadConfigWithYamlException(
      {
        'github': {'env': 'notAmap'},
      },
      r'''
line 2, column 8 of mono_repo.yaml: Unsupported value for "env". type 'String' is not a subtype of type 'Map<dynamic, dynamic>?' in type cast
  ╷
2 │   env: notAmap
  │        ^^^^^^^
  ╵''',
    ),
  );

  test(
    '"on_completion" does not allow setting "needs"',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'on_completion': [
            {
              'steps': [],
              'needs': ['foo'],
            }
          ]
        }
      },
      r'''
line 3, column 5 of mono_repo.yaml: Unsupported value for "on_completion". Cannot define a `needs` key for `on_completion` jobs, this is filled in for you to depend on all jobs.
  ╷
3 │ ┌     - steps: []
4 │ │       needs:
5 │ └         - foo
  ╵''',
    ),
  );

  test(
    '"on_completion" needs steps',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'on_completion': [{}]
        }
      },
      r'''
line 3, column 7 of mono_repo.yaml: Required keys are missing: steps.
  ╷
3 │     - {}
  │       ^^
  ╵''',
    ),
  );

  test(
    '"on_completion" needs one of `run` or `uses`',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'on_completion': [
            {
              'steps': [{}]
            }
          ]
        }
      },
      r'''
line 4, column 11 of mono_repo.yaml: Missing key "uses". Either `run` or `uses` must be defined.
  ╷
4 │         - {}
  │           ^^
  ╵''',
    ),
  );

  test(
    '"on_completion" cannot have run and uses',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'on_completion': [
            {
              'steps': [
                {
                  'run': 'bob',
                  'uses': 'bob',
                }
              ]
            }
          ]
        }
      },
      r'''
line 5, column 17 of mono_repo.yaml: Unsupported value for "uses". `uses` and `run` cannot both be defined.
  ╷
5 │           uses: bob
  │                 ^^^
  ╵''',
    ),
  );

  test(
    '"on_completion" cannot have with without uses',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'on_completion': [
            {
              'steps': [
                {
                  'run': 'bob',
                  'with': {},
                }
              ]
            }
          ]
        }
      },
      r'''
line 5, column 17 of mono_repo.yaml: Unsupported value for "with". `withContent` cannot be defined unless `uses` is defined.`
  ╷
5 │           with: {}
  │                 ^^
  ╵''',
    ),
  );

  test(
    'stages config only accepts a list',
    () => _testBadConfigWithYamlException(
      {
        'github': {'stages': 5}
      },
      r'''
line 2, column 11 of mono_repo.yaml: Unsupported value for "stages". `stages` must be an array.
  ╷
2 │   stages: 5
  │           ^
  ╵''',
    ),
  );

  test(
    'stages config only accepts a list of Strings or Maps',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'stages': [5]
        }
      },
      r'''
line 3, column 5 of mono_repo.yaml: Unsupported value for "stages". All values must be String or Map instances.
  ╷
3 │     - 5
  │     ^^^
  ╵''',
    ),
  );

  test(
    'stages only accepts known stage names',
    () => _testBadConfigWithUserException(
      {
        'github': {
          'stages': ['missing']
        }
      },
      'Error parsing mono_repo.yaml',
      expectedDetails: r'''
One or more stage was referenced in `mono_repo.yaml` that do not exist in any `mono_pkg.yaml` files: `missing`.''',
      // In this case there is some output printed before we get to the user
      // exception, but it isn't relevant.
      printMatcher: anything,
    ),
  );

  test(
    'conditional stages only accept string if values',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'stages': [
            {'name': 'foo', 'if': 1}
          ],
        }
      },
      r'''
line 4, column 11 of mono_repo.yaml: Unsupported value for "if". type 'int' is not a subtype of type 'String?' in type cast
  ╷
4 │       if: 1
  │           ^
  ╵''',
    ),
  );

  test(
    'conditional stages throw for unrecognized keys',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'stages': [
            {'foo': 'bar'}
          ],
        }
      },
      r'''
line 3, column 7 of mono_repo.yaml: Unrecognized keys: [foo]; supported keys: [name, if]
  ╷
3 │     - foo: bar
  │       ^^^
  ╵''',
    ),
  );

  group('workflows', _testWorkflows);
}

void _testWorkflows() {
  test(
    'must be a map',
    () => _testBadConfigWithYamlException(
      {
        'github': {'workflows': 'some value'}
      },
      r'''
line 2, column 14 of mono_repo.yaml: Unsupported value for "workflows". type 'String' is not a subtype of type 'Map<dynamic, dynamic>?' in type cast
  ╷
2 │   workflows: some value
  │              ^^^^^^^^^^
  ╵''',
    ),
  );

  test(
    'must have required keys',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'workflows': {'bob': {}}
        }
      },
      r'''
line 3, column 10 of mono_repo.yaml: Required keys are missing: name, stages.
  ╷
3 │     bob: {}
  │          ^^
  ╵''',
    ),
  );

  test(
    'cannot have extra keys',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'workflows': {
            'bob': {
              'name': 'bob',
              'stages': ['bob'],
              'extra': 42,
            }
          }
        }
      },
      r'''
line 7, column 7 of mono_repo.yaml: Unrecognized keys: [extra]; supported keys: [name, stages]
  ╷
7 │       extra: 42
  │       ^^^^^
  ╵''',
    ),
  );

  test(
    'stages cannot be empty',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'workflows': {
            'bob': {
              'name': 'bob',
              'stages': [],
            },
          },
        },
      },
      r'''
line 5, column 15 of mono_repo.yaml: Unsupported value for "stages". Cannot be empty.
  ╷
5 │       stages: []
  │               ^^
  ╵''',
    ),
  );

  test(
    'stages cannot have null values',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'workflows': {
            'bob': {
              'name': 'bob',
              'stages': [null],
            },
          },
        },
      },
      r'''
line 6, column 9 of mono_repo.yaml: Unsupported value for "stages". type 'Null' is not a subtype of type 'String' in type cast
  ╷
6 │         - null
  │         ^^^^^^
  ╵''',
    ),
  );

  test(
    'workflows cannot have the default key `$defaultGitHubWorkflowFileName`',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'workflows': {
            defaultGitHubWorkflowFileName: {
              'name': 'bob',
              'stages': ['existing'],
            },
          },
        },
      },
      r'''
line 3, column 5 of mono_repo.yaml: Unsupported value for "workflows". Cannot define a workflow with the default key "dart".
  ╷
3 │ ┌     dart:
4 │ │       name: bob
5 │ │       stages:
6 │ └         - existing
  ╵''',
    ),
  );

  test(
    'workflows cannot have the same name as the default '
    'workflow `$defaultGitHubWorkflowName`',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'workflows': {
            'wf1': {
              'name': defaultGitHubWorkflowName,
              'stages': ['existing'],
            },
          },
        },
      },
      r'''
line 4, column 13 of mono_repo.yaml: Unsupported value for "name". Cannot be the default workflow name "Dart CI".
  ╷
4 │       name: Dart CI
  │             ^^^^^^^
  ╵''',
    ),
  );

  test(
    'all defined stages must have corresponding jobs',
    () async {
      final monoConfigContent = toYaml(
        {
          'github': {
            'workflows': {
              'bob': {
                'name': 'bob',
                'stages': ['oops'],
              },
            },
          },
        },
      );
      await populateConfig(monoConfigContent);

      expect(
        () => testGenerateConfig(printMatcher: 'package:sub_pkg'),
        throwsUserExceptionWith(
          'No jobs are defined for the stage "oops" '
          'defined in GitHub workflow "bob".',
        ),
      );
    },
  );

  test(
    'two workflows cannot have the same stage',
    () => _testBadConfigWithYamlException(
      {
        'github': {
          'workflows': {
            'alice': {
              'name': 'alice',
              'stages': ['stage1'],
            },
            'bob': {
              'name': 'bob',
              'stages': ['stage1'],
            },
          },
        },
      },
      r'''
line 3, column 5 of mono_repo.yaml: Unsupported value for "workflows". Stage "stage1" is already defined in workflow "alice".
   ╷
3  │ ┌     alice:
4  │ │       name: alice
5  │ │       stages:
6  │ │         - stage1
7  │ │     bob:
8  │ │       name: bob
9  │ │       stages:
10 │ └         - stage1
   ╵''',
    ),
  );

  test(
    'two workflows cannot have the same name',
    () => _testBadConfigWithYamlException({
      'github': {
        'workflows': {
          'alice': {
            'name': 'bob',
            'stages': ['oops'],
          },
          'bob': {
            'name': 'bob',
            'stages': ['oops'],
          },
        },
      },
    }, r'''
line 3, column 5 of mono_repo.yaml: Unsupported value for "workflows". Workflows must have different names. Duplicate name(s): bob
   ╷
3  │ ┌     alice:
4  │ │       name: bob
5  │ │       stages:
6  │ │         - oops
7  │ │     bob:
8  │ │       name: bob
9  │ │       stages:
10 │ └         - oops
   ╵'''),
  );
}

Future<void> _testBadConfigWithYamlException(
  Object monoRepoYaml,
  Object expectedParsedYaml,
) async {
  final monoConfigContent = toYaml(monoRepoYaml);
  await populateConfig(monoConfigContent);
  expect(
    testGenerateConfig,
    throwsAParsedYamlException(expectedParsedYaml),
  );
}

Future<void> _testBadConfigWithUserException(
  Object monoRepoYaml,
  Object expectedMessage, {
  Object? expectedDetails,
  Object? printMatcher,
}) async {
  final monoConfigContent = toYaml(monoRepoYaml);
  await populateConfig(monoConfigContent);
  expect(
    () => testGenerateConfig(printMatcher: printMatcher),
    throwsUserExceptionWith(expectedMessage, details: expectedDetails),
  );
}
