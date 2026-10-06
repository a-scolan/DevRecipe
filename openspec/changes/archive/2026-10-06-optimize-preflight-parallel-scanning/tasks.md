## 1. OS Metadata Cache & Batch Evidence Gathering

- [x] 1.1 In `DevRecipe_windows.ps1`, implement `Initialize-DevRecipeWindowsOsMetadataCache` to collect registry uninstall records, App Paths, AppX packages, services, and tasks once before candidate scanning.
- [x] 1.2 Update `Find-DevRecipeWindowsOsMetadataEvidence` to query the in-memory cache when populated, falling back to direct system queries if called standalone.

## 2. Interactive Preflight Progress Tracking

- [x] 2.1 In `Invoke-DevRecipePreflight`, calculate step count and overall percentage across candidate entries, emitting `Write-Progress` and console milestone indicators.
- [x] 2.2 Mark progress as completed (`Write-Progress -Completed`) once all candidates have been audited.

## 3. Consolidated Preflight Summary (Bilan)

- [x] 3.1 In `Invoke-DevRecipePreflight`, suppress empty check headers for candidates without findings, displaying `--- PREFLIGHT CHECK: <name> ---` and trace details only when conflicts or traces are discovered.
- [x] 3.2 Ensure provider-managed items and coverage notes are rendered concisely as part of the preflight bilan before interactive prompts.

## 4. Verification and Quality Gates

- [x] 4.1 Update preflight acceptance tests in `tests/acceptance/test_baseline.py` to match streamlined header output and verify progress indication.
- [x] 4.2 Run fast unit tests and acceptance test suites (`py tests/acceptance/quality_gate.py`) and ensure clean execution without regressions.
- [x] 4.3 Validate the change with `openspec validate optimize-preflight-parallel-scanning --strict`.
