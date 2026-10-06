# Manually validate a DevRecipe change

> Documentation type: how-to guide. Use this page to test a changed manifest or recipe on a disposable host.

## Run the read-only modes first

From the repository root, run the commands for Windows PowerShell:

```powershell
./DevRecipe_windows.ps1 -Validate
./DevRecipe_windows.ps1 -List
./DevRecipe_windows.ps1 -DryRun
./DevRecipe_windows.ps1 -Status
```

Expected results are:

- validation returns success with no provider calls
- list reads only the manifest
- dry run prints prospective provider and bootstrap actions without mutation
- status reports provider evidence, not DevRecipe ownership

For an intentionally invalid manifest, verify a clear error and exit code `2` before any provider action.

## Verify installation boundaries

Use a disposable VM, test account, or approved non-production workstation.

1. Record the manifest revision, selected profiles, OS version, and provider versions.
2. Run dry run and review every bootstrap, privilege, repository, and provider action.
3. Run installation only when those effects are acceptable.
4. Run status and compare exact IDs with native provider inventories.
5. Confirm that DevRecipe does not create application configuration, launchers, or an ownership record.
6. On Windows, confirm `%LOCALAPPDATA%\mise\shims` is in the user `PATH`. Open a new `cmd.exe` and each available compatible shell. Verify one Mise-managed command in each new session.

Do not infer success from a command on `PATH`. Use the provider that owns the manifest entry.

## Verify preflight and review

Use a disposable host containing one selected provider ID and one unrelated OS metadata trace before testing preflight.

1. Run dry run. A concrete version match reports `decision=skip-no-action`. Standard Windows floating requests report `decision=check-update` and remain eligible for updates. OS conflicts include their query, source, scope, reason, similarity, and threshold.
2. Confirm that each entry shows no more than three OS records, that installation records rank before locations, and that incomplete sources produce coverage notes.
3. Run a conflicting command without a TTY. Confirm exit `3` and no package, bootstrap, or file mutation.
4. Run preflight in an interactive terminal. Test selection, decline, cancel, and checklist scrolling.
5. Run `-Review`. Confirm each checkpoint names the command, privilege, source or target, and effect. Refuse one checkpoint and confirm that later actions do not run.

Preflight is bounded, not a full-host inventory. Do not treat a clean result as proof that a host has no related application traces. See [preflight and review](preflight-and-review.md) for exact source coverage.

## Verify Windows maintenance and Node shims

Use a disposable Windows host. Do not replace an active workstation's shims with an affected release.

1. Install older selected Scoop applications and Mise. Also install an unrelated application that has an available update.
2. Run dry run. Make sure that it lists Scoop self-update, catalog refresh, Mise maintenance, and conditional selected updates without executing them.
3. Run installation. Make sure that Scoop updates before available versions are queried, and that Mise updates before Node work.
4. Compare provider inventories. Make sure that selected `latest` applications update, unrelated applications do not, and concrete pins remain unchanged.
5. Repeat with every selected component already installed. Make sure that maintenance still runs without forced reinstalls.
6. Repeat with only Scoop applications selected and Mise already installed. Make sure that Mise still receives its available update.
7. Test `node = "22"`, `node = "prefix:22"`, and `node = "lts"` separately. Make sure that updates respect the request.
8. Test `node = "^22"` and `node = "22.*"`. Make sure that an actionable error precedes host writes.
9. Select a Node version explicitly in the disposable host's Mise configuration. Record the active and installed versions.
10. Run installation with Mise 2026.10.1 or later. Make sure that `mise reshim --force` rebuilds existing shims and `node-ipc=passed` appears.
11. Make sure that the IPC result names the actual executable and active version, and reports any difference from the installed manifest version.
12. In an isolated test directory, rebuild a native executable shim with Mise 2026.9.3. Run the same IPC test to establish the failure.
13. Replace that isolated provider with the fixed release and rebuild its shim. Make sure that the same test passes.
14. Test missing version selection and an IPC timeout. Make sure that errors are explicit, temporary probe files disappear, and unrelated Node processes remain running.

The automated sandbox tests exercise command scope and failure handling, not native Windows handle inheritance.
The negative-control test must use the actual affected shim rather than a simulated command.
Restore or discard only the disposable environment after testing.

## Verify a narrow removal

Only test removal on a disposable host and only for a package whose removal is safe for that host.

1. Run the plan-only removal command for one exact declared ID.
2. Confirm it warns that provider presence does not establish DevRecipe ownership.
3. Confirm it names no bootstrap, configuration, container, remote, repository, user-data, or broad-cleanup action.
4. Repeat with `-Yes` (or `-y`) only after approving removal.
5. Verify the selected provider no longer lists the exact ID and that unrelated items remain untouched.

Test a rejected request too: choose an undeclared ID, an optional-profile ID without selecting that profile, or an ID not listed by the provider. Expected result: no removal command runs.

## Check container mode

Run `./DevRecipe_windows.ps1 -Containers -DryRun`; verify the Scoop bundle and UAC/virtualization boundary.

See [installation](installation.md#install-containers-separately) and [container provider policy](container-provider-policy.md) for details.

## Run local regression checks

Run `python tests/acceptance/developer_gate.py` for syntax, TOML, Markdown, and fast unit test checks. Run `python tests/acceptance/quality_gate.py` before completing a major release or change. It adds the full sandboxed acceptance suite. See [acceptance checks](../tests/acceptance/README.md) for prerequisites and limits.
