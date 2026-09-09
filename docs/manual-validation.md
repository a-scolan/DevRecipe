# Manually validate a DevRecipe change

> **Documentation type:** how-to guide. Use this page to check a changed manifest or recipe on a disposable host without treating DevRecipe as a lifecycle manager.

## Check read-only modes first

From the repository root, run the matching validation, list, dry-run, and status commands:

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

`DevRecipe_unix.bash` detects macOS or Linux and selects the matching manifest. Run each mode separately. Expected results:

- validation returns success with no provider calls;
- list reads only manifest content;
- dry run prints prospective bootstrap/provider actions with no mutation; and
- status reports exact declared-provider evidence, not DevRecipe ownership.

For an intentionally invalid manifest, verify a clear error and exit code `2` before any provider action.

## Verify an installation boundary

Use a disposable VM, test account, or approved non-production workstation.

1. Record the manifest revision, selected profiles, OS version, and relevant provider versions.
2. Run the matching dry-run and approve every displayed remote/bootstrap, privilege, repository, or remote-addition boundary.
3. Run normal installation only if those effects are acceptable.
4. Run status afterwards and compare exact raw IDs with native provider inventories.
5. Confirm selected default entries are submitted to their declared providers without DevRecipe-specific application configuration or launchers.
6. On Windows, if Mise entries are selected, confirm the user `PATH` contains `%LOCALAPPDATA%\mise\shims`, open a new `cmd.exe`, and verify a Mise-managed command is available. Also open each other compatible shell available on the host and confirm its startup hook that calls `mise activate <shell> --shims` makes a Mise-managed command available. Do not use an already-running terminal or VS Code process for this check because it keeps its inherited `PATH`.

Do not infer success from a command on `PATH`. Use the provider that owns the manifest entry.

## Verify preflight and review

Use a disposable host containing one selected provider ID and one unrelated OS metadata trace before testing preflight.

1. Run the matching dry-run. For an exact provider inventory match, confirm the entry is absent from both `PREFLIGHT CHECK` output and the final plan. For an OS metadata conflict, confirm evidence names the query, source, scope, match reason, `similarity=<value>/100`, and `threshold=90/100` without a write. Confirm no detected action renders more than three OS traces, installation or registration traces rank before locations and launchers, and incomplete-source lines or a filesystem coverage note remain visible.
2. Run preflight in an interactive terminal with at least two detected actions. On Windows or a capable Unix terminal, move with Up/Down, select one action with Space, and confirm with Enter; verify that only the unchecked action is omitted and each `decision=force` / `decision=decline` line identifies `application=<raw-id>`. Repeat with more detected actions than fit in the visible list: move down and up across both display edges, confirm the `more above` / `more below` indicators change, and verify a checked entry stays checked while off screen. Resize the terminal taller and confirm the visible list grows; reduce it below the checklist minimum and confirm the Unix prompt fallback. Move down past the final entry or press Tab, choose `[ Cancel ]` with the arrows, and confirm every detected action is omitted. On Unix, repeat with Escape and with `P`; confirm Escape declines all and `P` opens the one-by-one prompt. With `TERM=dumb` or a terminal too small for the checklist controls, confirm that Unix falls back to that prompt.
3. Run the same conflicting command without a TTY; confirm exit `3` and no package, bootstrap, or local-file mutation.
4. Run `-Review` / `--review` in an interactive disposable environment. Confirm every prompt shows command/target, privilege, source/target, and effect.
5. Refuse a checkpoint; confirm its action and subsequent actions do not run. Run review without a TTY and confirm exit `3` before mutation.

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

- Windows: run `./DevRecipe_windows.ps1 -Containers -DryRun`; verify the Scoop bundle and UAC/virtualisation boundary.
- macOS: run `bash ./DevRecipe_unix.bash --containers --dry-run`; verify the Homebrew Podman and absent-machine plan.
- Ubuntu/Debian: run `bash ./DevRecipe_unix.bash --containers --dry-run`; verify the APT Podman rootless bundle.

See [installation](installation.md#install-a-container-runtime-deliberately) and [container provider policy](container-provider-policy.md) for the platform routes.

## Run local regression checks

Run `python tests/acceptance/developer_gate.py` for syntax, TOML, and Markdown checks. Run `python tests/acceptance/quality_gate.py` before completing a change; it adds the fake-provider acceptance suite. See [acceptance checks](../tests/acceptance/README.md) for prerequisites and limits.
