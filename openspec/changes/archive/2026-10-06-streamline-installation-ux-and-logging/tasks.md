## 1. Workspace Logging Infrastructure

- [x] 1.1 In `DevRecipe_windows.ps1`, initialize the workspace log directory (`$PSScriptRoot/logs`) and create a timestamped log file (`logs/devrecipe-windows-<timestamp>.log`) to archive full execution output.
- [x] 1.2 Implement a logging helper `Write-DevRecipeLog` and pipe all raw provider stdout/stderr into the active log file.

## 2. Console Output Streamlining

- [x] 2.1 Update `Invoke-Scoop` to filter out low-level noise (shims, folder unlinking/linking, decompression, cache notices, post-install notices, and manifest notes) from console output.
- [x] 2.2 Ensure package download progress bars and hash verification remain visible on the console during package download and installation.

## 3. Global Multi-Package Progress Tracking

- [x] 3.1 Implement progress tracking with an accurate percentage calculation across both Scoop packages and Mise runtimes using `Write-Progress` and console milestone indicators (`[X/N (P%)]`).
- [x] 3.2 Update the progress indicator after each component is processed and mark it completed (`Write-Progress -Completed`) once all operations finish.

## 4. Post-Execution Structured Summary

- [x] 4.1 Collect component outcomes (`installed`, `updated`, `current`) throughout the installation run in an in-memory tracking list.
- [x] 4.2 Display a structured end-of-run summary categorizing components into Installed, Updated, and Current/Unchanged, and display the relative path to the generated workspace log file.

## 5. Verification and Quality Gates

- [x] 5.1 Update acceptance tests in `tests/acceptance/test_baseline.py` and `tests/acceptance/test_windows_maintenance.py` to assert log file creation, progress output formatting, and streamlined stdout.
- [x] 5.2 Run fast unit tests and acceptance test suites (`py -3 tests/acceptance/quality_gate.py`) and verify clean execution.
- [x] 5.3 Run `openspec validate streamline-installation-ux-and-logging --strict` to ensure spec and planning consistency.
