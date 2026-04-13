# mono_repo Reboot Plan (Updated)

This document outlines the strategy for simplifying `pkg:mono_repo` and making it more powerful for modern Dart monorepos.

## Goals

1.  **Simplify Configuration**: Reduce boilerplate in `mono_pkg.yaml`.
2.  **Smart Defaults**: Use information from `pubspec.yaml` to drive CI configuration.
3.  **Efficient CI**: Automatically generate path-based filters for GitHub Actions to only run necessary tests.
4.  **Workspace Awareness**: Support Dart workspaces by understanding internal dependencies and triggering downstream tests.
5.  **Simplify Implementation**: **Kill the "optimal merge" logic.** It is complex, hard to maintain, and no longer necessary for modern GitHub Actions.

## Proposed Changes

### 1. Simplify `mono_pkg.yaml`

Currently, `mono_pkg.yaml` often requires repeating SDKs and stages. We should support:

- **SDK Inference**: If `sdk` is omitted or set to `pubspec`, automatically test on:
  - **Oldest**: The minimum SDK version specified in `pubspec.yaml`.
  - **Newest**: The current `dev` (or `stable`) SDK.
- **Default Tasks**: If no tasks are specified, default to:
  - **Oldest SDK**: `dart analyze` and `dart test`.
  - **Newest SDK**: `dart format --output=none --set-exit-if-changed .`, `dart analyze --fatal-infos`, and `dart test`.
- **Repo-wide Defaults**: Move common configuration (like `oses`, `sdks`, or `stages`) to the root `mono_repo.yaml`.

### 2. Smart GitHub Action Generation

- **One Workflow Per Package**: Instead of a monolithic `dart.yml`, generate `.github/workflows/<package_name>.yaml`.
- **Automatic Path Filtering**: Each workflow will automatically include `paths` filters for its package directory and its own workflow file.
  - *Example:* `paths: ['pkgs/my_pkg/**', '.github/workflows/my_pkg.yaml']`
- **Kill Merge Logic**: Stop attempting to merge jobs across different packages into a single workflow. This simplifies the generator and makes individual package CI status clearer in the GitHub UI.
- **Workspace-aware Triggers**: If `package_b` depends on `package_a`, then a change in `package_a` should trigger the CI for `package_b`.

### 3. Workflow Improvements

- **SDK Management**: Better handling of Flutter vs. Dart SDKs.
- **Action Versions**: Keep GitHub Action versions (e.g., `actions/checkout@v4`) up to date easily (already partially supported but could be more robust).

## Implementation Strategy

### Phase 1: Research & Discovery (Done)
- Analyze current implementation of configuration parsing and YAML generation.
- Study existing "best-in-class" monorepo CI setups (like `tools`).

### Phase 2: Core Simplification & SDK Inference
- Update `PackageConfig.parse` to handle missing fields by looking at `pubspec.yaml` and `MonoConfig`.
- Implement SDK version extraction from `pubspec.yaml`'s `environment` block.
- Define the "Oldest" vs "Newest" SDK logic.

### Phase 3: New GitHub Action Generator
- Create a new generator that produces one workflow file per package.
- Implement path-based triggers (`on: push: paths:` and `on: pull_request: paths:`).
- Implement dependency graph analysis for the monorepo to support workspace-aware triggers (downstream testing).

### Phase 4: Refactoring & Cleanup
- Remove the legacy `groupCIJobEntries` and Travis-CI-era optimization logic.
- Simplify the internal "stage" and "job" models.

## Example of New `mono_pkg.yaml`

```yaml
# Minimal config!
# SDKs and tasks are entirely inferred.
```

## Example of Root `mono_repo.yaml` Defaults

```yaml
defaults:
  sdk: [pubspec, dev]
  os: [ubuntu-latest]
  stages:
    - analyze
    - test
```
