# Manage a DevRecipe manifest

> Documentation type: how-to guide. Use this page to change declarations, compare provider state, or remove one exact item.

The manifest defines installation requests. Application configuration, credentials, services, and provider-wide lifecycle remain outside DevRecipe.

## Add or change a tool

1. Find the exact ID in the provider that will install it (Scoop or Mise). Use the [provider documentation](package-matrix.md#provider-documentation).
2. Add it to `DevRecipe_windows.toml` under the narrowest suitable profile and category.
3. Use a non-empty version, such as `"latest"`, for an active entry.
4. Run validation, list mode, and dry run before installation.

| Need | TOML section |
| --- | --- |
| Windows package | `[packages.<profile>.os.<category>]` |
| Language runtime | `[runtimes.<profile>.mise.<category>]` |
| Versioned CLI | `[tools.<profile>.mise.<category>]` |

Quote keys that contain punctuation, such as `"npm:@github/copilot"`. Use `ai_agents` in TOML. Use `ai-agents` in command-line profile values.

The [package matrix](package-matrix.md) is the reference for the current IDs and details.

## Choose list or status

| Question | Mode | Effect |
| --- | --- | --- |
| What does the selected manifest declare? | `-List` | Reads the manifest only. |
| Does the declared provider list each exact entry? | `-Status` | Queries provider inventories. |
| What will installation submit? | `-DryRun` | Runs read-only preflight and prints the plan. |

Status is provider evidence. It does not prove that DevRecipe installed or owns an entry. Do not substitute an executable, display name, `PATH` result, or another provider's ID.

## Install an optional profile

`default` is always selected. Add profiles to the normal install command:

```powershell
./DevRecipe_windows.ps1 -Profile ai-agents,cloud
```

On Windows, `claude` requires an approved Scoop Extras bucket (configured automatically via `[buckets]`). See [Install DevRecipe](installation.md) before using this profile.

## Bypass preflight prompts with force

Installation and dry run perform preflight conflict detection. In unattended or automated execution where warnings are understood and accepted, use `-Force` to pre-approve detected non-fatal conflicts without prompting.

## Review writes

Installation and dry run run preflight automatically. Use `-Review` when a person must approve each host write. Review requires a real interactive terminal and applies to normal installation or confirmed removal, not list, status, validation, or dry run.

See the [preflight and review reference](preflight-and-review.md) for evidence sources, non-interactive behavior, approval rules, and exit codes.

## Remove one exact item

Removal is not rollback. It can remove an item that another person or tool installed.

1. Select an exact ID declared by the selected profiles.
2. Run the plan-only command.
3. Add explicit confirmation only when the removal is acceptable.

| Goal | Command |
| --- | --- |
| Plan only | `./DevRecipe_windows.ps1 -Uninstall git` |
| Confirm removal | `./DevRecipe_windows.ps1 -Uninstall git -Yes` (or `-y`) |

Select an optional profile in both commands. For example, use `./DevRecipe_windows.ps1 -Profile ai-agents -Uninstall claude -Yes`.

Before any removal, DevRecipe requires the provider to list every exact requested ID. If one condition fails, it removes nothing. It never removes provider bootstraps, dependencies, repositories, Mise configuration, containers, operating-system features, or user data. See the [status and removal reference](status-and-removal.md).

## Recover from an interrupted install

Read the provider error and use the provider's recovery process. DevRecipe has no installation journal, ownership database, automatic retry, global update mode, or universal rollback. Correct the manifest or provider prerequisite, run dry run again, and repeat installation only when the displayed effects are acceptable.

## Runtime activation and PATH precedence

Default language runtimes (`node`, `python`) without pre-existing installations are automatically activated globally (`mise use -g`). If an existing installation or active version is detected, DevRecipe preserves it without superseding.
Note that Windows grants `System PATH` precedence over `User PATH` for GUI applications (such as VS Code launched from Explorer or Start Menu). To use DevRecipe's shims in your editor, launch it from an initialized shell (`code .`).

## Install containers

Use `./DevRecipe_windows.ps1 -Containers` to run the separate container bundle. See [Install DevRecipe](installation.md#install-containers-separately) and the [container provider policy](container-provider-policy.md).
