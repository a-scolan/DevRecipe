## Why

Windows preflight treats any installed version as satisfying `latest` and removes that entry from the installation plan.
It also treats other Mise selectors as exact versions.
Repeated runs therefore miss provider and selected component updates, including the Windows Node IPC fix delivered in Mise 2026.10.1.

## What Changes

- On every approved standard Windows installation run, update Scoop itself and refresh its catalogs before resolving selected updates.
- Check and apply available updates to installed Scoop-managed Mise on those runs, even when no runtime installation is needed.
- Bootstrap Mise when approved selected work requires it. Do not install it solely for maintenance when it is absent and unneeded.
- Maintain all already-installed Scoop packages declared as `latest` in selected approved profiles, not only missing packages.
- Resolve supported floating Mise selectors such as `latest`, `22`, `prefix:22`, and backend-supported `lts` aliases, and install newer matching versions.
- Preserve the requested selector and its limits. Do not treat a matching `requested_version` record as proof of freshness.
- Do not interpret NPM ranges such as `^22`, `~22`, or `22.*` as general Mise command selectors. Reject unsupported requests explicitly.
- Maintain Mise through Scoop and require Mise 2026.10.1 or later for Windows Node shims.
- Rebuild Mise-owned shims after a Mise update and test Node IPC through the actual Windows shim. IPC is communication between a parent and child process.
- Keep exact declared versions, conflict decisions, application configuration, and existing Mise version selection unchanged.
- Keep validation, listing, status, removal, and dry run free of new update writes. Expose maintenance and update actions in dry run and review.
- Report provider, network, version, and shim failures without claiming success.
- Limit this change to the standard Windows recipe. Unix and the separate container bundle keep their existing behavior.

This intentionally changes repeated Windows installation runs from installed-item skipping to provider maintenance and selected-item updates.
Scoop packages use `latest`; Mise tools also use supported floating selectors.

## Capabilities

### New Capabilities

- `windows-provider-maintenance`: Update Scoop itself, maintain installed or required Scoop-managed Mise, and enforce the fixed Windows shim version.

### Modified Capabilities

- `preflight-conflict-detection`: Keep installed Windows Scoop `latest` entries and supported floating Mise requests eligible for updates without false version conflicts.
- `provider-routing`: Route selected Windows package updates to Scoop and show conditional actions without writes in dry run.
- `runtime-management`: Resolve supported floating Windows Mise requests within their declared limits and rebuild and test Windows Mise shims.

## Impact

Implementation will affect `DevRecipe_windows.ps1`, Windows provider fixtures in `tests/acceptance/test_baseline.py`, and related helper tests as needed.
Documentation will change in `README.md`, `docs/installation.md`, `docs/preflight-and-review.md`, and the Windows validation guidance.
No new dependencies, manifest fields, or CLI flags are planned.
Existing user edits to manifests and `docs/package-matrix.md` are outside this change.

Upstream evidence:

- [jdx/mise#13901](https://github.com/jdx/mise/issues/13901): Node IPC fails through the old Windows shim.
- [jdx/mise#13903](https://github.com/jdx/mise/pull/13903): Fixes inherited handles through the native shim.
- [Mise 2026.10.1](https://github.com/jdx/mise/releases/tag/v2026.10.1): First release with the fix.
- [Mise version scopes](https://mise.jdx.dev/configuration.html#scopes): Prefixes, aliases, and special version requests.
- [Mise latest](https://mise.jdx.dev/cli/latest.html): Read-only resolution of available matching versions.
- [Mise 2026.10.2 request parser](https://github.com/jdx/mise/blob/v2026.10.2/src/toolset/tool_request.rs): NPM ranges are not general command-argument selectors.
