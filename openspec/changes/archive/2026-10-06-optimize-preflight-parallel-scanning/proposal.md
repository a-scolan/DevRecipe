## Why

Currently, preflight conflict detection evaluates every declared package sequentially. For manifests with dozens of tools, this triggers repetitive queries against Windows registry paths, AppX package inventories, services, tasks, and filesystem locations for each individual tool.
Furthermore, the console output prints repetitive check blocks (`--- PREFLIGHT CHECK: <name> ---`) for all items even when no collision or trace is detected, lacking a unified visual progress indicator and a consolidated conflict summary.
Evaluating candidates in parallel against collected artifact state and rendering a clean progress bar with a consolidated findings summary dramatically reduces preflight run time and improves UX clarity.

## What Changes

- **Parallel / Batch Artifact Scanning**: Optimize preflight evidence discovery by collecting relevant OS registration, launcher, service, and application metadata once (or across concurrent background workers) and evaluating all target manifest entries in parallel, avoiding redundant sequential iterations over the entire OS inventory.
- **Preflight Progress Indication**: Display an interactive progress bar (`Write-Progress`) and console progress milestones `[X/N (P%)] Scanning <name>...` during preflight execution.
- **Consolidated Conflict Findings (Bilan)**: Suppress empty preflight check blocks for tools without findings. Present a single consolidated preflight summary highlighting only verified conflict traces, provider-managed items, and coverage notes before prompting for conflict resolution.

## Capabilities

### Modified Capabilities

- `preflight-conflict-detection`: Add requirement for progress tracking during preflight conflict scanning and streamline evidence output to present a consolidated conflict summary rather than printing empty per-item check headers.

## Impact

- Modifies `DevRecipe_windows.ps1` (`Invoke-DevRecipePreflight`, `Find-DevRecipeWindowsOsMetadataEvidence`, and related evidence collection helpers).
- Updates Windows acceptance tests (`tests/acceptance/test_baseline.py` and `tests/acceptance/test_windows_maintenance.py`) to align with streamlined preflight reporting and progress indication.
- Updates documentation (`docs/preflight-and-review.md`).
