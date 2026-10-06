# Start and customize DevRecipe

> Documentation type: tutorial. Use this page to make one safe manifest change.

DevRecipe reads `DevRecipe_windows.toml` and sends each selected identifier to its declared provider (Scoop or Mise). This tutorial enables one optional Mise runtime, validates the change, previews the plan, and installs it.

## Manifest and script

| Host | Manifest | Recipe |
| --- | --- | --- |
| Windows | `DevRecipe_windows.toml` | `./DevRecipe_windows.ps1` |

## Inspect the baseline

Open `DevRecipe_windows.toml` and find these sections:

- `[packages.default.*]` for operating-system packages and desktop applications;
- `[runtimes.default.mise.*]` for language runtimes; and
- `[tools.default.mise.*]` for versioned command-line tools.

`default` is always selected. The optional profile keys are `ai_agents` and `cloud`. Command-line profiles use hyphens, such as `ai-agents`. TOML keys use underscores, such as `ai_agents`.

Run validation and list mode before editing:

```powershell
./DevRecipe_windows.ps1 -Validate
./DevRecipe_windows.ps1 -List
```

Validation reads TOML only. List mode reads the selected declarations and does not call a provider.

## Enable one optional runtime

In the `runtimes.default.mise.optional` section, uncomment the existing Go entry:

```toml
[runtimes.default.mise.optional]
go = "latest"
```

Use an exact provider ID when you add another entry. Do not use an executable name from memory. Use the [package matrix](package-matrix.md) and the linked provider catalogues to find IDs. Keep optional tools in `ai_agents` or `cloud`, and keep daily tools in `default`.

## Validate, preview, and install

Run the commands in PowerShell:

```powershell
# Validate syntax and profile consistency
./DevRecipe_windows.ps1 -Validate

# Preview the execution plan without modifying the host
./DevRecipe_windows.ps1 -DryRun

# Execute the installation
./DevRecipe_windows.ps1
```

Dry run performs the read-only preflight and prints provider or bootstrap actions. It does not change the host. In a non-interactive terminal, an unresolved conflict returns exit code `3` and stops before mutation.

Use `-Review` when a person must approve every host write. Review needs a real interactive terminal. See the [preflight and review reference](preflight-and-review.md) for the decision rules.

## Verify the result

Run status with:

```powershell
./DevRecipe_windows.ps1 -Status
```

Status reports exact IDs known by the declared provider. It does not prove that DevRecipe installed or owns an item. See [Manage a DevRecipe manifest](user-guide.md) for optional profiles, removal, containers, and recovery.
