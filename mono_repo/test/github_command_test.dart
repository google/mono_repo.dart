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
    () => _testBadConfig(
      {
        'github': {'not_supported': 5}
      },
      r'''
line 2, column 3 of mono_repo.yaml: Unrecognized keys: [not_supported]; supported keys: [env, on, cron, workflows]
  ╷
2 │   not_supported: 5
  │   ^^^^^^^^^^^^^
  ╵''',
    ),
  );

  test(
    '"on" must be a Map',
    () => _testBadConfig(
      {
        'github': {'on': 'not a map'}
      },
      r'''
line 2, column 7 of mono_repo.yaml: Unsupported value for "on". type 'String' is not a subtype of type 'Map<dynamic, dynamic>' in type cast
  ╷
2 │   on: not a map
  │       ^^^^^^^^^
  ╵''',
    ),
  );

  test(
    'no cron with on',
    () => _testBadConfig(
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
    () => _testBadConfig(
      {
        'github': {'env': 'notAmap'},
      },
      r'''
line 2, column 8 of mono_repo.yaml: Unsupported value for "env". type 'String' is not a subtype of type 'Map<dynamic, dynamic>' in type cast
  ╷
2 │   env: notAmap
  │        ^^^^^^^
  ╵''',
    ),
  );

  group('workflows', _testWorkflows);
}

void _testWorkflows() {
  test(
    'must be a map',
    () => _testBadConfig(
      {
        'github': {'workflows': 'some value'}
      },
      r'''
line 2, column 14 of mono_repo.yaml: Unsupported value for "workflows". type 'String' is not a subtype of type 'Map<dynamic, dynamic>' in type cast
  ╷
2 │   workflows: some value
  │              ^^^^^^^^^^
  ╵''',
    ),
  );

  test(
    'must have required keys',
    () => _testBadConfig(
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
    () => _testBadConfig(
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
    () => _testBadConfig(
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
    () => _testBadConfig(
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
line 6, column 9 of mono_repo.yaml: Unsupported value for "stages". Stage values cannot be null.
  ╷
6 │         - null
  │         ^^^^^^
  ╵''',
    ),
  );

  test(
    'workflows cannot have the default key `$defaultGitHubWorkflowFileName`',
    () => _testBadConfig(
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
    () => _testBadConfig(
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
        () => testGenerateGitHubConfig(printMatcher: 'package:sub_pkg'),
        throwsUserExceptionWith(
          'No jobs are defined for the stage "oops" '
          'defined in GitHub workflow "bob".',
        ),
      );
    },
  );

  test(
    'two workflows cannot have the same stage',
    () => _testBadConfig(
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
    () => _testBadConfig({
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

Future<void> _testBadConfig(
  Object monoRepoYaml,
  Object expectedParsedYaml,
) async {
  final monoConfigContent = toYaml(monoRepoYaml);
  await populateConfig(monoConfigContent);
  expect(
    testGenerateGitHubConfig,
    throwsAParsedYamlException(expectedParsedYaml),
  );
}
