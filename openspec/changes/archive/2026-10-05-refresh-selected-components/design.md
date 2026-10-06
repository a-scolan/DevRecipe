## Context

See [the proposal](proposal.md) for the motivation and confirmed Windows-only scope.

`Get-ScoopEntryMatch` and `Get-MiseEntryMatch` treat `latest` as satisfied by any installed record.
`Invoke-DevRecipePreflight` excludes those records before the installation route runs.
It also compares non-`latest` requests literally or through `requested_version`, which does not distinguish a floating selector from an exact pin.
The Windows route calls only `scoop install` and `mise install`, then `mise reshim`.
It already retains selected Mise entries for shell activation after installation exclusions.

Scoop provides Mise in the default Windows manifest.
`Get-MiseCommand` resolves the first executable on PATH, which need not belong to Scoop.
The existing provider wrappers check exit codes, but Scoop output is discarded.
The revised path must expose required maintenance errors and update outcomes.

Mise 2026.10.1 contains the fix from jdx/mise#13903.
Its `reshim --force` command rebuilds Mise-owned shims.
Installing a runtime does not select it globally.
The existing specification explicitly preserves global Mise configuration.

Tests use provider stubs and temporary host directories in `tests/acceptance/test_baseline.py`.
They currently expect installed provider matches to disappear from the plan.
They also expect ordinary `reshim` calls and isolated PATH, shell, and registry writes.

## Goals / Non-Goals

Goals:

- Separate installed state, update eligibility, available versions, and completed actions.
- Maintain Scoop itself and installed Scoop-managed Mise even when every selected component is already installed.
- Preserve the limits of supported floating Mise requests instead of applying NPM range assumptions.
- Keep provider maintenance before operations that depend on updated provider behavior.
- Preserve conflict approval, exact-ID scope, review, and non-mutating modes.
- Prove Node shim compatibility with an IPC exchange, not only a version or `node --version` check.

Non-goals:

- No wildcard updates, removal of old runtime versions, forced reinstalls, or application configuration changes.
- No global or project Mise version selection changes.
- No Unix or separate container-route updates.
- No new maintenance policy flags, persistent freshness cache, or rollback engine.
- No automatic migration of external Mise installations into Scoop.

## Decisions

### 1. Keep provider matches separate from excluded actions

For the standard Windows installation, installed Scoop `latest` entries and supported floating Mise requests remain in an update-eligible set.
An installed concrete exact version still receives `decision=skip-no-action` for component installation only.
Use a separate decision such as `check-update` for installed floating requests.
Existing matches do not enter OS conflict scanning solely because an update is possible.
A declined action never enters the update set.
Keep approved selected Mise entries separately from runtime install exclusions.
An already-installed exact runtime can still require provider maintenance and shim verification.
Do not treat its no-install decision as a declined dependency.
Keep all approved selected entries separately from install exclusions so a fully installed manifest still triggers provider maintenance.

Do not change the shared inventory match result into a freshness claim.
Status and removal still need installed-state semantics.
Keep the container route on its existing exclusion policy.

The alternative is to bypass preflight for all installed items.
That loses conflict decisions and does not distinguish installed from current.

### 2. Maintain providers after decisions, before version resolution

The execution order is:

1. Validate the manifest and selected version selectors, then resolve conflicts without writes.
2. Exit dry run after showing conditional actions, or start review.
3. Bootstrap Scoop if needed.
4. Ensure Git is available before adding Git-backed buckets or maintaining Scoop. If absent, install the selected approved Git entry as a bootstrap prerequisite.
5. Ensure the declared buckets exist, then run `scoop update` to update Scoop itself and refresh its catalogs. Check the self-update and catalog outcomes.
6. Re-read installed state and available package versions with checked provider commands.
7. Check and update installed Scoop-managed Mise once, even without a selected runtime action. Bootstrap absent Mise only when approved selected work requires it.
8. Re-resolve its executable, verify provenance and version, then plan dependent Mise actions.
9. Install missing packages and update only selected eligible exact IDs.
10. Install selected Mise specifications, rebuild shims after provider replacement or approved selected Node work, and run applicable Node checks.

If Git is unavailable and no approved selected Git action can provide it, stop with an actionable prerequisite error.
Do not install unrelated prerequisites without approval.
Verify clean Git revisions for Scoop and every configured bucket against their remote branches after the refresh.
Do not accept a zero exit code as proof of success: Scoop can skip a held or dirty repository without a failing exit code.

Maintain Scoop on every approved standard Windows installation, including runs where every selected component is current or fixed.
Check and apply available updates to installed Scoop-managed Mise on those runs, even when the selected work has no Mise runtimes.
Do not install absent Mise solely for maintenance when it is not needed.
An explicit Mise package pin remains binding.
If that pin is incompatible with required Node shim behavior, stop instead of overriding it.
When no approved selected entries remain because all were declined, do not maintain providers.
Zero missing components does not mean zero approved selected entries.

Refreshing before conflict decisions would mutate the host on a refused or non-interactive run.
Refreshing all installed packages would exceed the selected manifest scope.

### 3. Use provider-native available versions and exact targets

Use refreshed Scoop metadata and machine-readable installed records.
For installed selected `latest` packages, compare provider versions and update exact raw IDs.
Every eligible installed package in the selected approved profiles participates on each run, not only when another package is missing.
Do not parse an English status table or run `scoop update *`.
Retain the existing path for missing or explicitly versioned package requests.

For Mise, resolve each approved supported floating declaration with its exact backend identifier, then submit its original `name@selector` specification.
Use checked remote resolution and force fresh version metadata where the supported Mise interface requires it.
Do not infer freshness from `mise ls --installed`.
Re-read installed inventory after writes and report the resolved installed version.
Avoid bare `mise upgrade`, which can operate on unrelated configured tools and remove old versions.

Use `mise install name@selector` rather than changing global configuration with `mise use`.
Do not reinstall a resolved version that is already installed.

### 4. Distinguish exact pins from supported floating requests

Mise 2026.10.2 supports partial versions, explicit `prefix:` scopes, and backend-specific aliases in addition to `latest`.
Delegate resolution to `mise latest name@selector` using fresh provider metadata and the original selector.
For example, `node@22` stays within Mise's resolution of that request instead of becoming `node@latest`.
`prefix:22` explicitly requests prefix matching even when a short exact version exists.
Alias resolution belongs to the backend and current Mise configuration.
Never accept `requested_version = "lts"` as proof that the installed version still matches the current alias.

Classify concrete pins, supported floating requests, and unsupported special requests before host writes.
Use the verified provider semantics rather than assuming every non-`latest` string is exact.
Preserve literal versions for non-SemVer backends instead of forcing them through a generic numeric parser.
Unsupported requests fail with their original selector and supported alternatives.

Mise 2026.10.2 warns that NPM ranges are unsupported for command arguments.
Its NPM range resolver applies to version requests sourced from `package.json`.
DevRecipe passes its own TOML values as arguments, so `^22`, `~22`, and `22.*` do not inherit that support.
Reject these requests before mutation rather than adding a separate NPM-compatible resolver.
Special requests such as `path:`, `system`, source references, or `sub-` scopes require an explicit maintenance policy.
Until that policy exists in this Windows route, reject them explicitly instead of treating them as exact pins or unrestricted latest.

Sources:

- [Mise scopes and aliases](https://mise.jdx.dev/configuration.html#scopes).
- [Mise latest](https://mise.jdx.dev/cli/latest.html).
- [Mise 2026.10.2 argument parser](https://github.com/jdx/mise/blob/v2026.10.2/src/toolset/tool_request.rs).
- [Mise 2026.10.2 version resolver](https://github.com/jdx/mise/blob/v2026.10.2/src/toolset/tool_version.rs).

### 5. Update Mise through Scoop and verify the executed binary

Match the resolved Mise executable with Scoop's managed installation and shims.
Do not assume that a Scoop inventory record proves that PATH selects that installation.
If the selected executable belongs to another provider, stop before dependent writes and name both locations.
When only Scoop applications are selected, still maintain installed Scoop-managed Mise and check for a shadowing executable.
This change does not add a second provider lifecycle to the Windows recipe.

After `scoop update mise` or bootstrap, resolve the command again.
Parse the reported version as a release version, ignoring architecture and build date.
For selected Node work, require at least 2026.10.1.
Unknown or prerelease versions without a reliable ordering fail the compatibility check.
A stale catalog or an incompatible explicit Mise pin produces a clear error.

An unconditional `mise self-update` can bypass package-manager ownership or leave Scoop metadata stale.
It is therefore not part of this Windows route.

### 6. Rebuild shims and test the actual failure

After replacing Mise or when approved selected Node work runs, use `mise reshim --force` to replace old Mise-owned executables.
This also repairs stale shims when Mise was updated outside DevRecipe before the run.
For runs without selected Node work or a provider replacement, keep ordinary `mise reshim`.
Preserve the existing user PATH, shell startup, and command processor integration.
Do not activate runtime versions globally.

For approved selected Node work, find the underlying Node executable for the parent probe without invoking the shim as the parent.
Launch the absolute user Node shim as the child with an IPC channel.
Send a unique message and require the matching reply within a bounded timeout, such as five seconds.
Capture spawn errors, premature exit, communication errors, and timeout as distinct failures.
Close the channel and terminate only the probe's tracked child process tree.
Include shim intermediary processes in timeout cleanup without using name-based process termination.
Any probe file is temporary and removed on success or failure.

Report the child executable and version, the resolved installed manifest version, and any difference.
A successful IPC test proves shim compatibility with the resolved Node target.
It does not prove that `latest` became the active version.
If existing configuration selects another version, explain the distinction without rewriting it.
If the shim cannot select any Node version, fail with instructions for explicit version selection.

A version check alone does not exercise inherited Windows handles.
Testing only the underlying `node.exe` avoids the shim and cannot detect the upstream regression.

### 7. Extend plans, review, tests, and documentation together

Add maintenance and conditional update lines to `Show-DryRunPlan`.
Dry run can query existing local state but cannot refresh catalogs or bootstrap missing providers.
Mark decisions based on old catalogs as provisional.
Every write goes through `Confirm-DevRecipeReviewAction`.
`-Force` remains conflict approval, not a forced reinstall or wildcard update.
`-SkipPreflight` skips conflict collection, not maintenance or minimum-version checks.

Extend fake providers with installed records, catalog versions, version output, update outcomes, and call-order logging.
Fake IPC outcomes test orchestration only.
A disposable Windows integration test must use the actual native shim to establish the IPC fix.
Do not run real provider updates on the developer workstation as an automated test.

Update installation, preflight, and Windows validation guidance.
Narrow the README boundary from no provider-wide maintenance to no unrelated application updates.
State that Scoop self-update, catalog refresh, and installed or required Mise maintenance are exceptions.
Document concrete pins, supported partial versions and aliases, and unsupported NPM range arguments.

## Risks / Trade-offs

- Network dependency: Freshness checks can fail offline. Report failure rather than claim current state.
- Scoop prerequisites: Fresh hosts can lack Git. Bootstrap only the approved selected Git entry or fail clearly.
- Catalog delay: Scoop can lag a Mise release. Fail the minimum-version check if the fixed release is unavailable.
- PATH ambiguity: Another Mise installation can shadow Scoop. Verify the binary rather than update an unused installation.
- Existing version selection: A newly installed latest Node can remain inactive. Report both installed and resolved versions.
- Partial completion: Native providers do not offer one transaction. Report completed actions and stop at the failing dependency.
- Shim files in use: Replacement can fail while another process uses a shim. Report the native failure and request a clean retry.
- Test limitations: Stubs cannot prove Windows handle inheritance. Keep an actual shim IPC test in manual validation.

## Migration Plan

No manifest migration is required.
Every approved standard Windows installation will maintain Scoop and installed or required Scoop-managed Mise.
Repeated runs will check selected Scoop `latest` entries and supported floating Mise requests rather than silently skip them.
Dry run exposes this behavior before writes.
Concrete exact versions, Unix execution, removal, and the container bundle retain their existing update policy.
Selected unsupported version requests now fail explicitly before host mutation instead of receiving misleading installed-state handling.

Ship targeted provider and mode regressions with the implementation.
Run the existing developer gate and affected Windows acceptance cases before the full local gate.
Run the native IPC probe on a disposable Windows host with a fixed Mise release and rebuilt shim.
For a negative control, demonstrate the old shim failure on that disposable host without changing the developer workstation.

Code rollback restores the previous recipe but does not undo native provider updates.
Keep older Mise runtime versions installed and document provider-native recovery.
