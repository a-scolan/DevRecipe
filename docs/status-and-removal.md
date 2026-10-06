# Status and narrow removal reference

> Documentation type: reference. This page defines provider status and exact-ID removal.

## Command modes

| Purpose | Windows command |
| --- | --- |
| Validate the manifest | `-Validate` |
| List manifest entries | `-List` |
| Show provider status | `-Status` |
| Print the install plan | `-DryRun` |
| Skip conflict checks | `-SkipPreflight` |
| Pre-approve conflicts with force | `-Force` (or `-f`) |
| Review each write | `-Review` |
| Print a removal plan | `-Uninstall <id>` |
| Confirm removal | `-Uninstall <id> -Yes` (or `-y`) |

Choose one primary mode. Manifest validation runs before each supported mode. Preflight applies to installation and dry run by default. Use `-SkipPreflight` to deactivate it. Use `-Force` to pre-approve detected conflicts. Review applies to installation and confirmed removal, and requires a real interactive terminal. See the [preflight and review reference](preflight-and-review.md) for decisions and exit codes.

## Status values and sources

| Status | Meaning |
| --- | --- |
| `installed` | The provider returned the declared ID or Mise specification. |
| `mismatch` | The provider lists the name, but not the declared explicit version. |
| `version-unavailable` | Windows Scoop lists the ID but does not expose a version for an explicit declaration. |
| `missing` | The accessible provider inventory does not list the entry. |
| `unavailable` | DevRecipe could not obtain the provider inventory. |

For `latest`, `installed` means that the provider reports an installed record for the name. The detected version is shown separately when the provider exposes it.

| Host | Provider | Inventory command |
| --- | --- | --- |
| Windows | Scoop packages | `scoop export` |
| Windows | Mise runtimes/tools | `mise ls --installed --json` |

Status is not provenance. It does not prove that DevRecipe installed, owns, can update, or can remove an item.

## Installation boundary

Installation forwards selected non-empty IDs to their declared provider. It does not transform IDs or infer ownership from status.

Mise installation uses exact `name@version` specifications. It does not create or change `~/.config/mise/config.toml` or run `mise use --global`. On Windows, selected Mise entries also run `mise reshim`, add `%LOCALAPPDATA%\mise\shims` and `%USERPROFILE%\scoop\shims` to the signed-in user's `PATH` for `cmd.exe` and new processes, configure `cmd.exe` AutoRun in `HKCU:\Software\Microsoft\Command Processor`, and add shell startup hooks for available compatible shells. DevRecipe does not change the system `PATH` or restart existing terminals and VS Code processes.

## Removal eligibility

All conditions below must hold:

1. The requested ID is declared exactly once by the selected profiles.
2. Its declared provider is available.
3. The provider currently lists the exact ID or Mise specification.
4. Every requested item passes its provider precondition before any removal starts.
5. The user supplies `-Yes` (or `-y`) after reading the plan.

Select optional profiles explicitly in both the plan and confirmation commands. If one condition fails, DevRecipe removes nothing.

## Removal commands

| Provider | Exact command |
| --- | --- |
| Scoop | `scoop uninstall <id>` |
| Mise | `mise uninstall <name>@<version>` |

Mise removals run before package-provider removals. DevRecipe does not remove provider bootstraps, dependencies, repositories, Mise configuration, shell startup entries, containers, user data, or operating-system features. It does not run provider-wide update, cleanup, or Scoop `-p`.