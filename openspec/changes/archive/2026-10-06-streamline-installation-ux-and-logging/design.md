## Context

See [proposal.md](proposal.md) for motivation.
Currently, `DevRecipe_windows.ps1` runs Scoop and Mise package installation directly through `Invoke-Scoop` and `Invoke-Mise`.
Scoop emits significant low-level noise on every package operation (shim management, directory symlinking, extraction, cache loading, post-install scripts, and long manifest notes).
Operators tracking a batch of 20+ applications currently see a flood of text without a global indicator of progress (percentage and step counts), and without an end-of-run recap of what was actually installed or updated versus already current.
Furthermore, troubleshooting detailed package outputs currently requires running manual commands or re-executing, because outputs are not saved into a workspace log file.

## Goals / Non-Goals

**Goals:**
- Provide a responsive global progress bar (`Write-Progress`) with accurate percentage calculation and `[X/N - P%]` step indicators covering the combined sequence of Scoop packages and Mise runtimes.
- Suppress low-level Scoop implementation traces (shims, unlinking/linking, extracting, post-install scripts, and manifest notes) from the console while preserving interactive download feedback and final outcomes.
- Record 100% of raw stdout/stderr from provider executions into a persistent timestamped file under `$PSScriptRoot/logs/`.
- Render a clear, structured post-execution summary categorizing treated components into Installed, Updated, and Current/Kept.

**Non-Goals:**
- Altering provider installation mechanics, manifest parsing, or package dependency resolution.
- Modifying Unix platform behavior (`DevRecipe_unix.bash`).
- Altering preflight conflict scanning heuristics or review approval logic.

## Decisions

### 1. Dedicated Workspace Logging
- Initialize a log file at startup or before provider writes:
  ```powershell
  $LogsDir = Join-Path $PSScriptRoot "logs"
  if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }
  $LogFile = Join-Path $LogsDir ("devrecipe-windows-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
  ```
- All provider commands (`scoop`, `mise`, git queries) write their complete, raw stdout and stderr to `$LogFile` via a helper function `Write-DevRecipeLog`.

### 2. Streamlined Console Filter
- In `Invoke-Scoop`, process output line-by-line:
  - Append every line directly to `$LogFile`.
  - Filter out noisy informational lines matching patterns:
    - Shims: `Removing shim`, `Creating shim`, `Making .* a GUI binary`
    - Links: `Linking ~\scoop`, `Unlinking ~\scoop`
    - Extraction & cache: `Extracting .* Done`, `Loading .* from cache`
    - Scripts: `Running (pre_|post_)?(un)?install script`
    - Manifest Notes blocks: between `Notes` and `-----`
    - Bucket commit logs: `^\s*\*\s+[0-9a-fA-F]{7,}\s+`
  - Retain on console:
    - Download lines and progress bars (`Downloading new version`, `\d+%\s*\[.*\]`)
    - Hash verification (`Checking hash ... OK`)
    - Completion and status (`.* was installed successfully!`, `updated | provider=...`)
- If an error occurs (non-zero exit code), the error output is written to the console and explicitly refers to the log file location for diagnostics.

### 3. Real Global Progress Bar with Percentage
- Compute total work items: `$TotalWorkCount = $OsEntries.Count + $SelectedMiseEntries.Count`.
- Track current index `$CurrentWorkIndex = 0`.
- Before each component operation:
  - `$CurrentWorkIndex++`
  - `$Percent = [Math]::Min(100, [Math]::Floor(($CurrentWorkIndex * 100.0) / [Math]::Max(1, $TotalWorkCount)))`
  - Call `Write-Progress -Activity "DevRecipe Installation" -Status "[$CurrentWorkIndex/$TotalWorkCount - $Percent%] $Provider: $ItemName" -PercentComplete $Percent`
  - Output a concise console milestone: `[$CurrentWorkIndex/$TotalWorkCount ($Percent%)] $ItemName ($Provider)`
- At the end of all installations: call `Write-Progress -Activity "DevRecipe Installation" -Completed`.

### 4. End-of-Run Component Recap
- Maintain an internal tracking list `$script:ProcessedComponents`:
  ```powershell
  [PSCustomObject]@{
      Name = $Entry.Name
      Provider = $Provider
      Outcome = "installed" | "updated" | "current"
      Version = $Version
      PreviousVersion = $PreviousVersion
  }
  ```
- Before exit, render a structured summary:
  ```text
  ============================================================
  INSTALLATION SUMMARY
  ============================================================
  Installed:
    - <name> (<version>)
  Updated:
    - <name> (<previous> -> <version>)
  Current / Unchanged:
    - <name> (<version>)

  Full execution log: logs/devrecipe-windows-<timestamp>.log
  ============================================================
  ```

## Risks / Trade-offs

- [Risk]: PowerShell `Write-Progress` may be slow or visually clipped in non-interactive CI/CD terminals.
  → Mitigation: Combine `Write-Progress` with a lightweight one-line console prefix `[$CurrentWorkIndex/$TotalWorkCount ($Percent%)]` that prints cleanly in any terminal environment, and gracefully catch any console UI exceptions.
- [Risk]: Suppressing notes might hide critical manual post-install instructions (such as registry scripts).
  → Mitigation: Log files preserve 100% of all notes and instructions. The post-execution summary highlights the log file path so operators can review provider notes whenever needed.
