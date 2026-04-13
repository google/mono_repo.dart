# Phase 3 & 4 Design: One Workflow Per Package

## 1. Overview
The current implementation of `mono_repo` tries to optimize CI by grouping jobs across different packages into a single `dart.yml` file. This logic (`groupCIJobEntries`) is complex and no longer necessary, as GitHub Actions handles concurrency and billing efficiently.

We will replace this with a **"One Workflow Per Package"** generator.

## 2. Changes in `generate.dart`
- Currently, `generateGitHubActions` calls `_GeneratedGitHubConfig.generate`, which returns a map of filenames to contents.
- We will keep this structure, but `generateGitHubYml` will now return multiple entries (one for each package, plus potentially a `mono_repo_self_validate.yaml`).
- `dependabot.yml` generation remains mostly unchanged, though we might want to ensure it aligns with the new workflow files.

## 3. Changes in `github_yaml.dart`
- **Remove `groupCIJobEntries`**: The complex grouping logic will be deleted.
- **`generateGitHubYml` Refactoring**:
  - Iterate over `rootConfig`. For each `packageConfig`:
    - Generate a workflow file named `.github/workflows/${packageConfig.relativePath.replaceAll('/', '_')}.yaml`.
    - Generate the `on` block with path filtering:
      ```yaml
      on:
        push:
          branches: [main, master]
          paths:
            - '.github/workflows/<pkg_name>.yaml'
            - '<pkg_path>/**'
            # Add downstream dependent paths here later for workspace support
        pull_request:
          branches: [main, master]
          paths:
            - '.github/workflows/<pkg_name>.yaml'
            - '<pkg_path>/**'
      ```
    - For each `CIJob` in `packageConfig.jobs`, create a GitHub Action `Job`. The job name can simply be based on the OS, SDK, and Stage, as it's already scoped to the package.
- **Self Validate**: Create a separate `.github/workflows/mono_repo_self_validate.yaml` if `self_validate` is enabled in `mono_repo.yaml`.

## 4. Execution Steps
1. Create a new `generate_per_package_workflows()` function in `github_yaml.dart` to replace `generateGitHubYml()`.
2. Implement the path filtering logic.
3. Update `_listJobs` to simply map `CIJob`s directly to GitHub `Job`s without grouping them across packages.
4. Update `mono_config.dart` to remove `merge_stages` as it is no longer relevant.
5. Remove `groupCIJobEntries` and related legacy grouping code.
