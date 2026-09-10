## Why

The Windows recipe previously contained hardcoded bucket names in PowerShell. To make package management flexible and fully generic without hardcoded software assumptions, Scoop buckets should be declared explicitly in `DevRecipe_windows.toml` under a top-level `[buckets]` section applied across all profiles.

## What Changes

- Add a top-level `[buckets]` section in `DevRecipe_windows.toml` listing required Scoop buckets (`extras = ""` and `versions = ""`, with optional custom repository URLs).
- Update the manifest schema and validators (`tests/acceptance/manifest_contract.py` and `DevRecipe_windows.ps1`) to recognize and validate the optional `[buckets]` table.
- Update `DevRecipe_windows.ps1` to read declared buckets dynamically from `[buckets]` and add any missing buckets via `Add-ScoopBucketIfAbsent`, removing hardcoded package name checks (`if ($PackageNames -contains "firefox-developer")`).
- Disclose declared buckets dynamically in `Show-DryRunPlan`.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `manifest-management`: Adds support for the optional `[buckets]` table in Windows TOML manifests.
- `provider-routing`: Dynamically resolves and registers Scoop buckets declared in `[buckets]` before installing packages on Windows.

## Impact

- `DevRecipe_windows.toml`: Added `[buckets]` section.
- `DevRecipe_windows.ps1`: Dynamic bucket parsing and registration, clean dry-run plan disclosure.
- `tests/acceptance/manifest_contract.py`: Allowed top-level `buckets` table.
- Specs: `manifest-management` and `provider-routing`.
