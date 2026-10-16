## Why

`DevRecipe_windows.ps1` always reads `DevRecipe_windows.toml` from its own folder (`$TomlPath`, line 29). An operator cannot run a different manifest, such as a reduced test manifest or a team-specific selection, without copying the whole recipe folder. This forced a staging workaround during a Java 21 + nmap + netcat run.

## What Changes

- Add a `-Manifest <path>` parameter to `DevRecipe_windows.ps1` that selects the TOML manifest used by every mode (validate, list, status, dry run, installation, uninstall, and containers).
- A relative path is resolved against the current working directory. An absolute path is used as is.
- When `-Manifest` is omitted, the script keeps reading `DevRecipe_windows.toml` next to the script. Existing commands behave the same.
- A missing or unreadable path fails through the existing manifest validation path: exit code 2, a line-level diagnostic naming the path, and no changes.
- `-Manifest` is not a mode switch. It can be combined with any mode.
- Document the parameter in the user-facing docs (`docs/installation.md`, `docs/user-guide.md`).

No **BREAKING** changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `cli-interface`: adds the `-Manifest <path>` option and its exit-code behavior for a missing file.
- `manifest-management`: the manifest source is selectable by path instead of fixed to the script folder. Validation, profile resolution, and declaration integrity apply to the selected file.

## Impact

- Code: `DevRecipe_windows.ps1` (parameter block, the `$TomlPath` definition, and every reader of the manifest: validation, `Get-Content`, `Get-ContainerPackages`, `Invoke-ContainerFeatureSetup` path, and the "Valid manifest" message).
- Logs: the `logs/` folder stays next to the script. This is an assumption, recorded in the design.
- Tests: acceptance tests in `tests/acceptance/test_baseline.py` and `tests/acceptance/manifest_contract.py` gain cases for an explicit path.
- Docs: `docs/installation.md`, `docs/user-guide.md`, `docs/quick-start.md` mention the option.
- Not affected: provider commands (Scoop, Mise), preflight rules, the default manifest content, and the logs location.

## Non-goals

- No support for several manifests in one run.
- No change to how the default manifest is shipped or edited.
- No change to the `DEVRECIPE_TEST_*` environment overrides.
