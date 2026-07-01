# Phase 5 Review Feedback & Fixes

## 🔴 Blocking Issues
- [ ] **1. The `pull_request` Workflow Trigger Bypass** (`github_yaml.dart`): Handle `null` case for `pull_request` trigger to correctly inject `paths` filter.
- [ ] **2. Transitive `devDependencies` BFS Flaw** (`github_yaml.dart`): Only aggregate `devDependencies` for the starting package in `transitiveDeps()`, not for every node.
- [ ] **3. `preSteps` Execute Before Repository Checkout** (`github_yaml.dart`): Move `preSteps` immediately after the `checkout` step in `_githubJob`.
- [ ] **4. `isNewest` Logic Silently Dropping Explicit Tasks** (`package_config.dart`): Calculate `isNewest` based on the SDKs configured for that specific job (`jobSdks`), not the global package `sdks`.

## 🟠 Moderate Issues
- [ ] **5. Non-Deterministic Task Keys** (`generate.dart`): Sort `commands` (`.toList()..sort()`) before assigning indices in `extractCommands`.
- [ ] **6. Ignored Packages Still Run in Local Commands** (`root_config.dart`): Filter out ignored packages explicitly in `visitDirectory` using `monoConfig.ignore.contains(relativeSubDirPath)`.
- [ ] **7. Shallow Merge of Cascading Defaults** (`package_config.dart`): Revisit or document shallow merge behavior for `stages` and `cache` vs deep merge.
- [ ] **8. Overly Broad `paths` Filter for Root Packages** (`github_yaml.dart`): Fix paths filter for packages at the root (`.`) to prevent `/**` matching everything.

## 🟡 Nitpicks & Minor Flaws
- [ ] **9. Loss of YAML Context in `defaults` Validation** (`package_config.dart`): Fix `YamlMap` context preservation when merging defaults.
- [ ] **10. O(N²) Algorithmic Inefficiency in `_listJobs`** (`github_yaml.dart`): Optimize lookup `rootConfig.singleWhere` by passing `PackageConfig` or caching it.
- [ ] **11. Code Duplication: `extractCommands`** (`generate.dart` & `github_yaml.dart`): Unify `extractCommands` into `ci_shared.dart`.
- [ ] **12. Redundant Package Names in Job Names** (`github_yaml.dart`): Disable or clean up redundant package name prefixing since we now use per-package workflows.
