# Manually validate a DevRecipe change

> Documentation type: how-to guide. Use this page to test a changed manifest or recipe on a disposable host.

## Run the read-only modes first

From the repository root, run the commands for the host under test:

```text
Windows:       ./DevRecipe_windows.ps1 -Validate
Windows:       ./DevRecipe_windows.ps1 -List
Windows:       ./DevRecipe_windows.ps1 -DryRun
Windows:       ./DevRecipe_windows.ps1 -Status
macOS:         bash ./DevRecipe_unix.bash --validate
macOS:         bash ./DevRecipe_unix.bash --list
macOS:         bash ./DevRecipe_unix.bash --dry-run
macOS:         bash ./DevRecipe_unix.bash --status
Ubuntu/Debian: bash ./DevRecipe_unix.bash --validate
Ubuntu/Debian: bash ./DevRecipe_unix.bash --list
Ubuntu/Debian: bash ./DevRecipe_unix.bash --dry-run
Ubuntu/Debian: bash ./DevRecipe_unix.bash --status
```

`DevRecipe_unix.bash` detects macOS or Linux and selects the matching manifest. Run each mode separately. Expected results are:

- validation returns success with no provider calls
- list reads only the manifest
- dry run prints prospective provider and bootstrap actions without mutation
- status reports provider evidence, not DevRecipe ownership

For an intentionally invalid manifest, verify a clear error and exit code `2` before any provider action.

## Verify installation boundaries

Use a disposable VM, test account, or approved non-production workstation.

1. Record the manifest revision, selected profiles, OS version, and provider versions.
2. Run dry run and review every bootstrap, privilege, repository, remote, and provider action.
3. Run installation only when those effects are acceptable.
4. Run status and compare exact IDs with native provider inventories.
5. Confirm that DevRecipe does not create application configuration, launchers, or an ownership record.
6. On Windows, confirm `%LOCALAPPDATA%\mise\shims` is in the user `PATH`. Open a new `cmd.exe` and each available compatible shell. Verify one Mise-managed command in each new session.

Do not infer success from a command on `PATH`. Use the provider that owns the manifest entry.

## Verify preflight and review

Use a disposable host containing one selected provider ID and one unrelated OS metadata trace before testing preflight.

1. Run dry run. For an exact provider match, confirm `PREFLIGHT PROVIDER-MANAGED STATE` reports `decision=skip-no-action` and the entry is absent from the final plan. For an OS conflict, confirm the evidence includes its query, source, scope, reason, similarity, and threshold.
2. Confirm that each entry shows no more than three OS records, that installation records rank before locations, and that incomplete sources produce coverage notes.
3. Run a conflicting command without a TTY. Confirm exit `3` and no package, bootstrap, or file mutation.
4. Run preflight in an interactive terminal. Test selection, decline, cancel, scrolling, and the Unix `P` fallback.
5. Run `-Review` or `--review`. Confirm each checkpoint names the command, privilege, source or target, and effect. Refuse one checkpoint and confirm that later actions do not run.

Preflight is bounded, not a full-host inventory. Do not treat a clean result as proof that a host has no related application traces. See [preflight and review](preflight-and-review.md) for exact source coverage.

## Verify a narrow removal

Only test removal on a disposable host and only for a package whose removal is safe for that host.

1. Run the plan-only removal command for one exact declared ID.
2. Confirm it warns that provider presence does not establish DevRecipe ownership.
3. Confirm it names no bootstrap, configuration, container, remote, repository, user-data, or broad-cleanup action.
4. Repeat with `-Yes` / `--yes` only after approving removal.
5. Verify the selected provider no longer lists the exact ID and that unrelated items remain untouched.

Test a rejected request too: choose an undeclared ID, an optional-profile ID without selecting that profile, or an ID not listed by the provider. Expected result: no removal command runs.

## Check container mode

- Windows: run `./DevRecipe_windows.ps1 -Containers -DryRun`; verify the Scoop bundle and UAC/virtualization boundary.
- macOS: run `bash ./DevRecipe_unix.bash --containers --dry-run`; verify the Homebrew Podman and absent-machine plan.
- Ubuntu/Debian: run `bash ./DevRecipe_unix.bash --containers --dry-run`; verify the APT Podman rootless bundle.

See [installation](installation.md#install-containers-separately) and [container provider policy](container-provider-policy.md) for the platform routes.

## Run local regression checks

Run `python tests/acceptance/developer_gate.py` for syntax, TOML, Markdown, and fast unit test checks. Run `python tests/acceptance/quality_gate.py` before completing a major release or change. It adds the full sandboxed acceptance suite. See [acceptance checks](../tests/acceptance/README.md) for prerequisites and limits.
