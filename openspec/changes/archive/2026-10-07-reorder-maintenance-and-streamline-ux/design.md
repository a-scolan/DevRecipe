## Context

See [proposal.md](proposal.md) for motivation.
Currently, `DevRecipe_windows.ps1` runs preflight conflict detection prior to updating Scoop and Mise. As a result, version matching and conflict evaluation use local provider state rather than refreshed remote catalogs.
In addition, `Invoke-NativeMultiSelect` fails to activate in compact terminals due to rigid viewport minimums and potential buffer height bounds errors, and console output includes verbose traces for already-added buckets and already-current tools.

## Goals / Non-Goals

**Goals:**
- Move Scoop self-update, bucket validation, and Mise provider maintenance to run before existing installation detection and version decision making on standard Windows installation runs.
- Present conflict scanning with clear functional terminology: `--- EXISTING INSTALLATIONS DETECTION ---`.
- Make `Invoke-NativeMultiSelect` resilient in constrained terminals (allowing visible rows down to 1 row when few rows are available) and clamp cursor positioning to `[Console]::BufferHeight - 1`.
- Suppress noisy logs for default buckets when already configured and omit repetitive status lines for applications that are already current.
- Add a succinct, clear action summary block in English detailing planned Scoop and Mise actions.

**Non-Goals:**
- Changing Linux/macOS Unix script execution flow.
- Changing conflict scoring algorithms (Levenshtein distance and prefix heuristics remain unchanged).
- Mutating providers or buckets during non-mutating modes (`-DryRun`, `-Validate`, `-List`, `-Status`).

## Decisions

### 1. Reorder Provider Maintenance Before Existing Installation Detection
- On standard installation runs (when not in `-DryRun`, `-Validate`, `-List`, `-Status`), bootstrap Scoop/Git, ensure declared buckets, run `scoop update`, and ensure Mise provider is updated.
- Then run `Invoke-DevRecipePreflight` (renamed functionally in header display as existing installations detection). Preflight now queries fresh Scoop inventory and updated catalogs, allowing exact-version and floating-version comparisons against up-to-date metadata.

### 2. Compact and Robust TUI Viewport
- Relax `Get-DevRecipePreflightViewport`: allow `$MinimumVisibleRows = 1`. If available lines are small (e.g. 5–8 rows), show 1–2 rows with scrolling indicators rather than returning `$null`.
- When calculating `$Top`, clamp to `[Math]::Max(0, [Math]::Min([Console]::BufferHeight - $MenuLines - 1, [Console]::CursorTop))`.
- When clearing and redrawing lines, ensure line length never exceeds `[Console]::WindowWidth - 1` and never write past `[Console]::BufferHeight - 1`.

### 3. Trace Streamlining & Functional Banner
- In `Add-ScoopBucketIfAbsent`, avoid printing messages if the bucket is already in `scoop bucket list`.
- In preflight output, display `--- EXISTING INSTALLATIONS DETECTION ---` instead of `--- PREFLIGHT CONFLICT EVIDENCE (read-only) ---`.
- Suppress output for `current | provider=Scoop` unless verbose mode is requested, or summarize them concisely.

### 4. Structured Action Summary
- Format the planned action display as:
  ```text
  DevRecipe will proceed to [install | uninstall | install and update] Scoop applications:
    - <package> (<status or version>)
  and runtime environments with Mise:
    - <runtime> (<status or version>)
  ```

## Risks / Trade-offs

- [Risk]: Updating Scoop and buckets requires internet connectivity before conflict detection.
  → Mitigation: Network failures during initial provider refresh stop with a clean actionable error as required by provider maintenance specifications. In `-DryRun`, provider mutation is skipped.
- [Risk]: Acceptance tests expect specific strings in `stdout`.
  → Mitigation: Update tests in `test_baseline.py` and `test_windows_maintenance.py` to match the functional terminology and updated output format.
