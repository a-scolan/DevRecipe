## Why

On Windows, Scoop only initializes the `main` bucket by default. Many declared tools in `DevRecipe_windows.toml` (such as `dbeaver`, `vscode`, `obsidian`, `vlc`, `powertoys`) reside in the `extras` bucket, and `firefox-developer` resides in the `versions` bucket. Currently, base installation does not ensure these buckets are added before running `scoop install`, causing installations of packages like `dbeaver` to fail with "Couldn't find manifest". Additionally, `Install-ContainerPackages` attempts to run `scoop bucket add extras versions` in a single invalid invocation.

## What Changes

- Add an `Ensure-ScoopBucket` helper in `DevRecipe_windows.ps1` that checks `scoop bucket list` and cleanly adds missing buckets.
- Automatically ensure the `extras` bucket (and `versions` bucket when `firefox-developer` is requested) is added before installing Windows packages.
- Fix the bucket addition syntax in `Install-ContainerPackages` to add buckets individually.
- Disclose bucket additions in `Show-DryRunPlan` ("Scoop: add the extras bucket if absent.").

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `provider-routing`: On Windows, ensure required secondary Scoop buckets (`extras`, `versions`) are configured before installing packages that depend on them.

## Impact

- `DevRecipe_windows.ps1`: `Show-DryRunPlan`, `Ensure-ScoopBucket`, installation loop, and `Install-ContainerPackages`.
- Documentation in `docs/installation.md` and `docs/user-guide.md` if needed.
