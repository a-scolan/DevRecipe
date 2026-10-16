## 1. Script parameter and manifest path resolution

- [x] 1.1 Search `DevRecipe_windows.ps1` for existing `$Manifest` variables and confirm no local variable shadows the new parameter; verify the search result is recorded in the commit notes
- [x] 1.2 Add `[string]$Manifest` to the `param` block and replace the fixed `$TomlPath` assignment with the resolution from design.md (`GetUnresolvedProviderPathFromPSPath` when bound, default path otherwise); verify `-Validate` without the option still reads `DevRecipe_windows.toml`
- [x] 1.3 Reject an empty or whitespace-only `-Manifest` with `Stop-Usage` before any manifest read; verify it exits with code 2

## 2. Behavior verification

- [x] 2.1 Add acceptance cases in `tests/acceptance/test_baseline.py` for `-Manifest` with a relative path, an absolute path outside the script folder, and a missing path; verify each case passes and the missing path exits with code 2 with the path in the diagnostic
- [x] 2.2 Add an acceptance case that combines `-Manifest` with `-List` and `-DryRun` and checks that only the selected file's entries appear; verify the case passes
- [x] 2.3 Add an acceptance case for `-Manifest` with `-Containers -DryRun` that reads `[containers.default.os.*]` from the selected file; verify the container package list matches the selected file
- [x] 2.4 Run the acceptance tests covering the manifest and CLI contracts (`tests/acceptance/manifest_contract.py` and `tests/acceptance/test_baseline.py`) and verify they pass without calling real package providers

## 3. Documentation

- [x] 3.1 Document `-Manifest <path>` in `docs/installation.md` (command table) and in `docs/user-guide.md` (manifest selection section); verify both pages link to each other consistently and the example command runs with `-Validate`
- [x] 3.2 Update the manifest path wording in `docs/quick-start.md` to mention the option; verify the relative link checks in `tests/acceptance/markdown_links.py` pass

## 4. Validation

- [x] 4.1 Run `openspec validate add-manifest-path-parameter --strict` and verify it reports the change as valid

## 5. Provider stderr handling (added during apply)

- [x] 5.1 Run `scoop` and `mise` native commands with a local ErrorActionPreference of `Continue` in `Invoke-Scoop` and `Invoke-Mise`, restoring it in `finally`; verify `mise install` progress written to stderr no longer aborts the run (`test_windows_provider_progress_on_stderr_does_not_abort_install` passes)

