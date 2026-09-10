## Context

See proposal.md - Why.
In Scoop on Windows, packages from the default recipe `DevRecipe_windows.toml` belong to multiple buckets:
- Core utilities belong to `main`.
- Desktop applications (`dbeaver`, `vscode`, `obsidian`, `powertoys`, etc.) belong to `extras`.
- Developer browser editions (`firefox-developer`) belong to `versions`.
Without ensuring these buckets are added before `scoop install`, Scoop fails immediately when attempting to locate package manifests for applications like `dbeaver`.

## Goals / Non-Goals

**Goals:**
- Provide an `Ensure-ScoopBucket` function in `DevRecipe_windows.ps1` that checks `scoop bucket list` and executes `scoop bucket add <bucket>` individually.
- Automatically ensure `extras` is configured when Windows package installations run, and ensure `versions` is configured if `firefox-developer` is declared.
- Update `Show-DryRunPlan` to explicitly disclose bucket additions.
- Fix `Install-ContainerPackages` to avoid passing multiple bucket names to a single `scoop bucket add` invocation.

**Non-Goals:**
- Removing or altering buckets during uninstallation (buckets are shared infrastructure).

## Decisions

### Decision 1: Inspect `scoop bucket list` Before Mutating
- **Rationale**: Idempotent check ensures that if `extras` or `versions` is already configured, no unnecessary commands or review checkpoints are emitted.

### Decision 2: Disclose in Dry-Run Plan
- **Rationale**: DevRecipe commits to showing planned changes before execution. Disclosing "Scoop: add the extras bucket if absent." maintains full transparency.

## Risks / Trade-offs

- [Risk] Network or Git failure when adding buckets from GitHub.
  → Mitigation: Standard Scoop error handling applies; review checkpoint permits human verification.
