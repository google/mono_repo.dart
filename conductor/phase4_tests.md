# Test Modernization Plan

## Problem
The shift to the "One Workflow Per Package" model and smart SDK defaults has broken the majority of tests in `mono_repo/test/generate_test.dart` and the expected outputs in `mono_repo/test/src/expected_output.dart`. The tests still expect:
1.  A monolithic `.github/workflows/dart.yml` file instead of per-package files.
2.  The presence of obsolete configuration keys like `merge_stages`.
3.  The absence of the `pubspec` SDK requirement for basic tasks.

## Solution Strategy
We must surgically update the test suite to align with the new architectural reality without losing the core validation logic.

### Step 1: Update Test Utilities (`test/shared.dart`)
-   Ensure all instances of `d.file('pubspec.yaml', ...)` include the `environment: sdk: '^3.0.0'` block, as our smart defaults logic now mandates a valid pubspec environment for inferring the minimum SDK version. All packages are assumed to be at least Dart ^3.0.0.

### Step 2: Refactor `generate_test.dart`
-   **Replace Monolithic Assertions**: Everywhere a test asserts `Wrote \`.github/workflows/dart.yml\``, it must be updated to expect `Wrote \`.github/workflows/<pkg_name>.yml\``.
-   **Remove Obsolete Configuration**: Strip out any `merge_stages` configurations from test inputs.
-   **Update Path Expectations**: Tests verifying path filtering need to reflect the automated inclusion of `paths: ['pkgs/<pkg>/**', '.github/workflows/<pkg>.yaml']`.

### Step 3: Refresh Expected Outputs (`test/src/expected_output.dart` & `test/script_integration_outputs/`)
-   Many tests do exact string matching against large YAML or shell scripts. Since the entire structure has changed (e.g., no more cross-package grouping, `task.command(isNewest)` logic), we will run the tests, capture the *new* valid output, and update the golden files and string constants.
-   Specifically, `githubConfigOutput` and `ciScript` constants need a complete refresh to match the new one-workflow-per-package reality.

### Step 4: Specific Bug Fixes
-   `test/action_versions_test.dart`: Update to ensure it reads from the new per-package workflow files rather than the legacy `dart.yml`.
-   Fix the `pubspec` vs `flutter` tests that failed due to mismatched line numbers in the exception messages.

## Execution
I will systematically apply these changes, prioritizing `generate_test.dart` and `shared.dart`, followed by a mass refresh of the golden files.
