## 1. Schema and Validator Updates

- [x] 1.1 Add `buckets` to `KNOWN_TOP_LEVEL_SECTIONS` and validation in `tests/acceptance/manifest_contract.py`
- [x] 1.2 Update manifest parser in `DevRecipe_windows.ps1` to accept and parse `[buckets]`
- [x] 1.3 Add `[buckets]` section with `extras = ""` and `versions = ""` in `DevRecipe_windows.toml`

## 2. Dynamic Bucket Resolution Implementation

- [x] 2.1 Update `DevRecipe_windows.ps1` to extract declared buckets and ensure each one via `Add-ScoopBucketIfAbsent`
- [x] 2.2 Update `Show-DryRunPlan` in `DevRecipe_windows.ps1` to dynamically display each declared bucket
- [x] 2.3 Remove hardcoded `firefox-developer` checks from `DevRecipe_windows.ps1`

## 3. Verification and Acceptance

- [x] 3.1 Run `python tests/acceptance/developer_gate.py` to confirm contracts and unit tests pass
- [x] 3.2 Verify `powershell -File DevRecipe_windows.ps1 -DryRun -SkipPreflight` displays the declared buckets
