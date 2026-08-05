# Manage a DevRecipe manifest

> **Documentation type:** how-to guide. Use this page to change a reviewed manifest, inspect provider state, or remove one declared item.

The manifest controls installation requests. Customise it for your workstation, then configure installed applications separately.

## Add or change a tool

1. Find the raw identifier in the provider that will install it. The [provider documentation](package-matrix.md#provider-documentation) links to the authoritative catalogues and command guides.
2. Add it to the matching platform TOML file under the narrowest suitable profile and category.
3. Use a non-empty version such as `"latest"` for an active entry.
4. Validate, list, and dry-run the changed manifest before installation.

Use the manifest layout below:

| Need | Section |
| --- | --- |
| Windows, macOS formula, or Linux APT package | `[packages.<profile>.os.<category>]` |
| macOS desktop application | `[packages.<profile>.cask.<category>]` |
| Linux desktop application | `[packages.<profile>.flatpak.<category>]` |
| Language runtime | `[runtimes.<profile>.mise.<category>]` |
| Versioned CLI | `[tools.<profile>.mise.<category>]` |

Use quoted TOML keys for IDs containing punctuation, for example `"npm:@github/copilot"` or a Flatpak application ID. `default` is always selected; use `ai_agents` and `cloud` only for optional capabilities. The [package matrix](package-matrix.md) describes current provider choices.

## Default behaviour

No option runs the non-empty `default` entries. Add optional profiles and containers explicitly. A normal installation may bootstrap its declared provider; `--list` / `-List`, `--validate` / `-Validate`, and dry-run remain read-only. Preflight is automatic for installation and dry run, and `--preflight` / `-Preflight` is an explicit equivalent. On Windows, `-Containers` uses `-ContainerProvider Auto` unless overridden.

## Inspect declared and provider state

`--list` / `-List` reads only the manifest. `--status` / `-Status` asks native providers about exact selected IDs.

| Host | Manifest only | Provider status |
| --- | --- | --- |
| Windows | `./DevRecipe_windows.ps1 -List` | `./DevRecipe_windows.ps1 -Status` |
| macOS | `bash ./DevRecipe_unix.bash --list` | `bash ./DevRecipe_unix.bash --status` |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash --list` | `bash ./DevRecipe_unix.bash --status` |

`DevRecipe_unix.bash` detects macOS or Linux and selects the matching manifest.

Do not use a matching executable, app name, `PATH` result, or another provider's inventory as evidence for a manifest ID. A status match proves only that the selected provider knows that exact ID; it does not prove who installed it.

## Install an optional profile

Add a profile to the ordinary install command:

```text
Windows:       ./DevRecipe_windows.ps1 -Profile ai-agents,cloud
macOS:         bash ./DevRecipe_unix.bash --profile ai-agents,cloud
Ubuntu/Debian: bash ./DevRecipe_unix.bash --profile ai-agents,cloud
```

## Inspect conflict evidence or review every write

Normal installation and dry-run already run read-only preflight. If it reports a local conflict in an interactive terminal, decide whether to force or decline its exact declared entry; declining it affects only that entry. An unresolved conflict in automation stops before mutation.

Use review when a person must approve every host write, including provider bootstrap, package operations, configuration, privileged features, or confirmed removal:

| Host | Command |
| --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Review` |
| macOS / Ubuntu-Debian | `bash ./DevRecipe_unix.bash --review` |

The [preflight and review reference](preflight-and-review.md) defines explicit preflight mode, evidence sources, terminal controls, approval rules, option restrictions, and exit codes.

## Remove one declared provider ID

Removal is an escape hatch for a failed or unwanted installation, not a rollback engine.

1. Choose an exact raw ID declared by the current selected profiles.
2. Run the plan-only command and read its warning.
3. Run the confirmation command only if removing that provider ID is acceptable.

| Host | Plan only | Confirm |
| --- | --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Uninstall git` | `./DevRecipe_windows.ps1 -Uninstall git -Yes` |
| macOS | `bash ./DevRecipe_unix.bash --uninstall git` | `bash ./DevRecipe_unix.bash --uninstall git --yes` |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash --uninstall git` | `bash ./DevRecipe_unix.bash --uninstall git --yes` |

To remove an optional-profile entry, select that profile in both commands. For example, use `-Profile ai-agents -Uninstall claude -Yes` on Windows, or `--profile ai-agents --uninstall claude --yes` on macOS.

Before mutating, DevRecipe checks every requested item in its selected provider. If one preflight check fails, it removes nothing. It only calls a narrow provider command for each exact ID. It does not remove provider bootstraps, dependencies, repositories, Flatpak remotes, user configuration (including Mise), containers, operating-system features, or user data.

The [status and removal reference](status-and-removal.md) names exact provider checks and commands. If the provider did not list the ID, DevRecipe refuses removal rather than guessing.

## Recover from an interrupted install

Read the provider error and use the provider's documented recovery process; the official links are in [provider documentation](package-matrix.md#provider-documentation). DevRecipe intentionally has no installation journal, ownership database, automatic retry, global update mode, or universal rollback. Re-run a dry-run after correcting a manifest or provider prerequisite; only rerun normal installation when its effects are acceptable.

## Containers

The base recipes install container runtimes only when you explicitly select their integrated container mode. Use `./DevRecipe_windows.ps1 -Containers` or `bash ./DevRecipe_unix.bash --containers`. These commands run only their declared container bundle, not the normal baseline. See the [installation guide](installation.md#install-a-container-runtime-deliberately) for platform boundaries and the [Windows provider policy](container-provider-policy.md) before changing Windows virtualisation features.
