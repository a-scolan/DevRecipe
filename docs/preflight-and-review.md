# Preflight and review reference

> Documentation type: reference. This page defines conflict evidence and per-action approval.

## When the modes run

| Purpose | Windows command |
| --- | --- |
| Inspect conflict evidence | `./DevRecipe_windows.ps1 -DryRun` |
| Bypass conflict checks | `./DevRecipe_windows.ps1 -SkipPreflight` |
| Pre-approve conflicts with force | `./DevRecipe_windows.ps1 -Force` (or `-f`) |
| Review each installation write | `./DevRecipe_windows.ps1 -Review` |
| Review each confirmed removal write | `./DevRecipe_windows.ps1 -Uninstall git -Yes -Review` |

Preflight runs automatically for installation and dry run, including the container bundle. Use `-SkipPreflight` to deactivate it. Preflight does not run for validation, list, status, or removal. Review applies to installation and confirmed removal, but not dry run, and requires a real interactive terminal. All modes validate the manifest first.

## Conflict preflight

Preflight is a bounded read-only audit. It checks the declared provider inventory first, then local OS evidence.

An installed concrete version match appears under `PREFLIGHT PROVIDER-MANAGED STATE` with `decision=skip-no-action`.
It needs no component installation, but remains approved work for standard Windows provider maintenance.
On Windows, Scoop uses `scoop export` and Mise uses `mise ls --installed --json`.
A different concrete version produces `provider-conflict` and needs the normal force or decline decision.

Standard Windows installation keeps installed Scoop `latest` entries and supported floating Mise requests with `decision=check-update`.
Floating requests select matching releases, for example `22`, `prefix:22`, or the Node alias `lts`.
Their installed state does not prove freshness and does not create an OS conflict by itself.
On standard Windows installations, Scoop updates itself and its catalogs, and checks installed or required Scoop-managed Mise before existing installations detection. DevRecipe announces this audit functionally as `--- EXISTING INSTALLATIONS DETECTION ---`.
An installed matching alias does not bypass fresh Mise resolution.
Declined entries never enter installation or update actions.
Windows container provider matches retain their existing skip policy.

Preflight does not contact a registry to prove freshness.
Dry-run decisions remain provisional until catalog refresh, which dry run never performs.
`-SkipPreflight` bypasses conflict scanning only. It does not disable maintenance or Node compatibility checks.
`-Force` approves conflicts only. It does not force reinstallations or wildcard application updates.

Provider-managed state does not prove DevRecipe ownership or provenance. Remaining entries are compared with bounded local OS evidence. The comparison is case-insensitive and uses a Levenshtein similarity of at least `90/100`, or a separator-flexible prefix match. For example, `firefox-developer` can match `FirefoxDeveloper Edition`, but `git` does not match `GitHub`. Each evidence record includes its query, source, scope, location, value, reason, similarity, and threshold. Each entry shows at most three OS records. Installation and registration records rank before locations, launchers, services, and tasks. The result does not prove package identity, ownership, or permission to remove anything.

The shipped Windows collector is bounded and staged:

| Host | Sources currently queried |
| --- | --- |
| Windows | Versioned Scoop export; machine-readable Mise installed inventory; uninstall and App Paths registry views; AppX registrations; bounded approved application and Start Menu roots; service and scheduled-task names |

Unavailable sources produce coverage notes. They do not prove that no conflict exists. Provider notes identify an unbootstrapped provider or a failed inventory command. Windows groups incomplete filesystem checks into one coverage note. The collectors do not scan application contents, follow links or reparse points, or send data off the host.

During scanning, an interactive progress indicator reports current scan progress and percentage. Candidates without traces or version collisions are checked cleanly without flooding the console. When evidence or provider conflicts are discovered, DevRecipe outputs `--- PREFLIGHT CHECK: <query> ---` and presents the matching traces. In an interactive terminal, DevRecipe then asks whether to continue with that exact type, provider, ID, and version. The default is decline. A refusal removes only that action from the final plan. Entries without evidence remain in the plan.

The Windows console shows an unchecked checklist. Use Up and Down to move, Space to toggle, and `A` to select or deselect all. Use Tab or move past the last entry to reach the buttons. Enter confirms the selected actions. Escape or Cancel declines all detected actions. In a non-interactive terminal, an unresolved conflict exits `3` before mutation.

## Interactive review

Review displays a checkpoint before each planned host write. It names the command or target, privilege, source or target, and expected effect. Windows also shows conflict traces before a selected installation action. Enter `y` or `yes` to approve one action. Uppercase `A` approves the current and remaining actions. Any other response, closed input, or missing TTY exits `3` before the current action runs. `-Yes` confirms a removal plan only. It never bypasses review.

Review can cover provider bootstraps, package indexes, repositories, installs and removals, Windows Mise shim activation, Windows optional features, WSL configuration, UAC setup, and the optional Docker compatibility alias. It does not change profiles, IDs, providers, provider arguments, or action order. A successful review runs the same operations as normal execution and does not create an installation or ownership record.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | The requested mode completed. |
| `2` | The command or manifest contract is invalid. |
| `3` | A preflight or review decision is unresolved or refused, or review has no usable interactive terminal. |

Provider and operating-system failures can return another non-zero code. Read the provider output. Use [manual validation](manual-validation.md) on a disposable host.