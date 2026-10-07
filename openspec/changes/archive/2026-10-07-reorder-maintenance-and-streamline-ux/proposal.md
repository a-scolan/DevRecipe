## Why

Windows installation currently delays Scoop and Mise maintenance until after preflight conflict decisions, meaning preflight operates against potentially stale local provider metadata.
Furthermore, preflight terminal outputs are overly verbose with excessive traces (such as default bucket checks and repetitive logs for already-current packages), use confusing technical terminology instead of functional descriptions, and fail to display the interactive TUI selection menu in constrained VS Code terminal panels.

## What Changes

- Run Scoop self-update, bucket refresh, and Mise maintenance before existing installation detection and version decision making on standard Windows installation runs.
- Present preflight conflict scanning functionally in English as "Existing installations detection" (`--- EXISTING INSTALLATIONS DETECTION ---`).
- Make the interactive TUI selection menu (`Invoke-NativeMultiSelect`) robust in compact terminal viewports (adapting visible rows down to 1 item when terminal height is constrained and avoiding console buffer edge overflow).
- Eliminate noisy, repetitive traces: suppress default bucket queries/traces when already present and omit repetitive status messages for already-current applications.
- Output a clear, concise summary of intended actions in English before proceeding:
  "DevRecipe will proceed to [install | uninstall | install and update] Scoop applications:
  - <list of Scoop packages with status/version>
  and runtime environments with Mise:
  - <list of Mise runtimes/tools with status/version>"

## Capabilities

### Modified Capabilities

- `windows-provider-maintenance`: Reorder provider self-maintenance to run before existing installation detection and version decisions, and suppress default bucket and already-current trace noise.
- `preflight-conflict-detection`: Present preflight functionally as existing installations detection, and ensure the interactive TUI multi-select menu renders reliably in constrained terminal viewports.
- `cli-interface`: Display a concise structured summary of Scoop applications and Mise runtime environments to be installed, updated, or removed.

## Impact

- Modifies `DevRecipe_windows.ps1`.
- Updates acceptance test suites (`test_baseline.py` and `test_windows_maintenance.py`) to align with the new execution order, streamlined output format, and TUI viewport tolerances.
- Updates documentation (`docs/preflight-and-review.md`, `README.md`, `docs/manual-validation.md`) to reflect the functional terminology and updated output flow.
