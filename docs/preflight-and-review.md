# Preflight and review reference

> Documentation type: reference. This page defines conflict evidence and per-action approval.

## When the modes run

| Purpose | Windows | macOS or Ubuntu/Debian |
| --- | --- | --- |
| Inspect conflict evidence | `./DevRecipe_windows.ps1 -DryRun` | `bash ./DevRecipe_unix.bash --dry-run` |
| Bypass conflict checks | `./DevRecipe_windows.ps1 -SkipPreflight` | `bash ./DevRecipe_unix.bash --skip-preflight` |
| Pre-approve conflicts with force | `./DevRecipe_windows.ps1 -Force` | `bash ./DevRecipe_unix.bash --force` (or `-f`) |
| Review each installation write | `./DevRecipe_windows.ps1 -Review` | `bash ./DevRecipe_unix.bash --review` |
| Review each confirmed removal write | `./DevRecipe_windows.ps1 -Uninstall git -Yes -Review` | `bash ./DevRecipe_unix.bash --uninstall git --yes --review` |

`DevRecipe_unix.bash` detects macOS or Linux and selects the matching manifest. Preflight runs automatically for installation and dry run, including the container bundle. Use `-SkipPreflight` or `--skip-preflight` to deactivate it. Preflight does not run for validation, list, status, or removal. Review applies to installation and confirmed removal, but not dry run, and requires a real interactive terminal. All modes validate the manifest first.

## Conflict preflight

Preflight is a bounded read-only audit. It checks the declared provider inventory first, then local OS evidence.

An exact provider match is reported under `PREFLIGHT PROVIDER-MANAGED STATE` with `decision=skip-no-action` and is removed from the installation plan. On Windows, Scoop uses the version from `scoop export`. Mise uses `mise ls --installed --json`. An explicit manifest version must match an installed record. `latest` accepts the provider's installed record and reports its detected version. Preflight does not contact a registry to prove freshness. A different explicit version is reported as `provider-conflict` and needs the normal force or decline decision.

Provider-managed state does not prove DevRecipe ownership or provenance. Remaining entries are compared with bounded local OS evidence. The comparison is case-insensitive and uses a Levenshtein similarity of at least `90/100`, or a separator-flexible prefix match. For example, `firefox-developer` can match `FirefoxDeveloper Edition`, but `git` does not match `GitHub`. Each evidence record includes its query, source, scope, location, value, reason, similarity, and threshold. Each entry shows at most three OS records. Installation and registration records rank before locations, launchers, services, and tasks. The result does not prove package identity, ownership, or permission to remove anything.

The shipped collector is bounded and staged:

| Host | Sources currently queried |
| --- | --- |
| Windows | Versioned Scoop export; machine-readable Mise installed inventory; uninstall and App Paths registry views; AppX registrations; bounded approved application and Start Menu roots; service and scheduled-task names |
| macOS | Homebrew formula/cask lists; exact Mise installed-spec query; package-receipt IDs; names from `/Applications`, `~/Applications`, user application-support, launch-agent, and shortcut metadata |
| Ubuntu/Debian | `dpkg-query`; user Flatpak list; exact Mise installed-spec query; names from desktop-entry, `/opt`, `/usr/local`, XDG application-data, user-service, and user-configuration metadata |

Unavailable sources produce coverage notes. They do not prove that no conflict exists. Provider notes identify an unbootstrapped provider or a failed inventory command. Unix scans approved metadata roots once per preflight, use depth two and at most 2,000 non-link names per root, and redact user-home paths as `<home>`. Windows groups incomplete filesystem checks into one coverage note. The collectors do not scan application contents, follow links or reparse points, or send data off the host.

Each remaining entry begins with `--- PREFLIGHT CHECK: <query> ---`. When evidence is found in an interactive terminal, DevRecipe asks whether to continue with that exact type, provider, ID, and version. The default is decline. A refusal removes only that action from the final plan. Entries without evidence remain in the plan.

The Windows console and capable Unix terminals show an unchecked checklist. Use Up and Down to move, Space to toggle, and `A` to select or deselect all. Use Tab or move past the last entry to reach the buttons. Enter confirms the selected actions. Escape or Cancel declines all detected actions. On Unix, `P` switches to one-by-one prompts when the checklist is unavailable. That prompt accepts `A` or `all yes`, and `D` or `all no`. In a non-interactive terminal, an unresolved conflict exits `3` before mutation.

## Interactive review

Review displays a checkpoint before each planned host write. It names the command or target, privilege, source or target, and expected effect. Windows also shows conflict traces before a selected installation action. Enter `y` or `yes` to approve one action. On Windows, uppercase `A` approves the current and remaining actions. Any other response, closed input, or missing TTY exits `3` before the current action runs. `-Yes` or `--yes` confirms a removal plan only. It never bypasses review.

Review can cover provider bootstraps, package indexes, repositories and remotes, installs and removals, Windows Mise shim activation, Windows optional features, WSL configuration, UAC setup, and the optional Docker compatibility alias. It does not change profiles, IDs, providers, provider arguments, or action order. A successful review runs the same operations as normal execution and does not create an installation or ownership record.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | The requested mode completed. |
| `2` | The command or manifest contract is invalid. |
| `3` | A preflight or review decision is unresolved or refused, or review has no usable interactive terminal. |

Provider and operating-system failures can return another non-zero code. Read the provider output. Use [manual validation](manual-validation.md) on a disposable host.