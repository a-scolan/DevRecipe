## 1. Implementation

- [x] 1.1 Add `Ensure-ScoopBucket` helper in `DevRecipe_windows.ps1` to inspect and add buckets cleanly
- [x] 1.2 Integrate bucket initialization (`extras`, and `versions` if `firefox-developer` is present) into `DevRecipe_windows.ps1` before `scoop install`
- [x] 1.3 Fix bucket addition in `Install-ContainerPackages` to call `Ensure-ScoopBucket`
- [x] 1.4 Update `Show-DryRunPlan` to disclose missing bucket additions

## 2. Verification

- [x] 2.1 Run `python tests/acceptance/developer_gate.py` to confirm syntax and contracts pass
- [x] 2.2 Verify dry-run plan output includes bucket disclosure on Windows
