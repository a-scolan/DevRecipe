## Context

See [proposal.md](proposal.md) for motivation.
Currently, `Invoke-DevRecipePreflight` iterates sequentially over each declared manifest entry.
In each iteration, it queries system-wide metadata:
- Registry uninstall keys (`HKCU`, `HKLM`, `WOW6432Node`)
- Command lookup (`Get-Command`)
- Registry App Paths
- AppX package inventory (`Get-AppxPackage`)
- Cached filesystem scan
- Win32 services (`Win32_Service`)
- Scheduled tasks (`Get-ScheduledTask`)

For a standard manifest containing 30–40 tools, this triggers dozens of repetitive, slow WMI/CIM and registry iterations.
Furthermore, every tool unconditionally outputs a console header (`--- PREFLIGHT CHECK: <name> ---`), flooding the terminal with empty check headers even when zero traces exist, with no progress bar tracking overall preflight completion.

## Goals / Non-Goals

**Goals:**
- Optimize preflight scanning performance by snapshotting or parallelizing OS metadata collection across all candidate installation items.
- Provide a smooth, real-time progress bar (`Write-Progress`) and console indicator displaying progress count and percentage across all preflight evaluations.
- Deliver a clean, consolidated preflight summary (bilan): suppress empty check headers for clean tools and display trace details only for items with detected collisions or version mismatches.

**Non-Goals:**
- Changing Levenshtein distance logic, similarity scoring ($90/100$), or prefix matching rules.
- Altering the interactive conflict resolution workflow (`Invoke-NativeMultiSelect` or `Read-Host`).
- Modifying behavior for non-Windows platforms or non-installation modes.

## Decisions

### 1. Unified OS Metadata Snapshot / Concurrent Evaluation
- Implement an in-memory snapshot helper `Initialize-DevRecipeWindowsOsMetadataCache` that gathers system-wide inventory data (registry uninstall records, App Paths, AppX packages, services, scheduled tasks) once per preflight run.
- Keep `Find-DevRecipeWindowsOsMetadataEvidence` fully backward-compatible: if the cache is populated, evaluate against the in-memory cache; if not, query on demand (ensuring custom test harnesses and preludes continue to function without modification).

### 2. Interactive Preflight Progress Bar
- During preflight execution, track item progression:
  ```powershell
  $PreflightIndex = 0
  $TotalPreflight = $Entries.Count
  foreach ($Entry in $Entries) {
      $PreflightIndex++
      $Percent = [Math]::Min(100, [Math]::Floor(($PreflightIndex * 100.0) / [Math]::Max(1, $TotalPreflight)))
      try {
          Write-Progress -Activity "Preflight Conflict Detection" -Status "[$PreflightIndex/$TotalPreflight - $Percent%] Checking $($Entry.Name)" -PercentComplete $Percent
      } catch {}
      ...
  }
  try { Write-Progress -Activity "Preflight Conflict Detection" -Completed } catch {}
  ```

### 3. Consolidated Preflight Findings (Bilan)
- Clean tools with zero traces are evaluated silently while the progress bar updates.
- If an item produces conflict traces or provider version mismatches:
  - Display `--- PREFLIGHT CHECK: <name> ---` and list prioritized traces under `Traces found for '<name>:'`.
- Conclude preflight with:
  - `Show-DevRecipePreflightProviderMatches` (provider-managed state)
  - `Show-DevRecipeWindowsFilesystemCoverage` (coverage notes, if any)
  - Followed by the interactive conflict checklist prompt if conflicts remain.

## Risks / Trade-offs

- [Risk]: Existing acceptance tests might stub `Find-DevRecipeWindowsOsMetadataEvidence` directly.
  → Mitigation: The caching layer feeds into `Find-DevRecipeWindowsOsMetadataEvidence`, so any test override of `Find-DevRecipeWindowsOsMetadataEvidence` remains fully authoritative.
- [Risk]: Some tests may assert the exact count of `--- PREFLIGHT CHECK: <query> ---` for clean tools.
  → Mitigation: Audit existing tests in `test_baseline.py` and ensure headers remain displayed when conflicts are detected, updating tests that specifically expect clean tools to omit empty headers.
