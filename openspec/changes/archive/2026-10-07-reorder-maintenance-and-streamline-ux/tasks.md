## 1. Reordering Provider Maintenance

- [x] 1.1 In `DevRecipe_windows.ps1`, move Scoop bootstrap, bucket verification, `scoop update`, and Mise provider maintenance before preflight conflict detection in standard execution mode, keeping non-mutating modes (`-DryRun`, `-Validate`, `-List`, `-Status`) non-mutating.
- [x] 1.2 Ensure preflight conflict detection receives refreshed provider inventory and catalog state so version matching and update eligibility are evaluated against fresh data.

## 2. Interactive TUI Menu Robustness

- [x] 2.1 Update `Get-DevRecipePreflightViewport` in `DevRecipe_windows.ps1` to allow a minimum of 1 visible row (`$MinimumVisibleRows = 1`) and calculate row allocation dynamically for compact terminals.
- [x] 2.2 In `Invoke-NativeMultiSelect`, ensure cursor positioning is safely clamped against `[Console]::BufferHeight - 1` and menu lines do not overflow window width or trigger out-of-range console exceptions.

## 3. Output Streamlining and Functional Language

- [x] 3.1 Update preflight header text to use functional wording in English: `--- EXISTING INSTALLATIONS DETECTION ---` and describe scanning for existing installations.
- [x] 3.2 Suppress redundant bucket addition traces when buckets are already configured, and eliminate repetitive status lines for already-current packages.
- [x] 3.3 Add the structured action summary block before installation or update execution ("DevRecipe will proceed to [action] Scoop applications: ... and runtime environments with Mise: ...").

## 4. Verification and Quality Gates

- [x] 4.1 Update baseline and Windows maintenance tests in `tests/acceptance/test_baseline.py` and `tests/acceptance/test_windows_maintenance.py` to match the new execution sequence, updated banner text, and compact TUI calculations.
- [x] 4.2 Run fast developer checks and targeted acceptance checks, keeping test executions parsimonious.
- [x] 4.3 Validate the change with `openspec validate reorder-maintenance-and-streamline-ux --strict`.
