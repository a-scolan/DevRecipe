# Default preflight and interactive review reference

> **Documentation type:** reference. This page defines DevRecipe conflict preflight and per-action review behaviour.

## Commands

| Purpose | Windows | macOS / Ubuntu-Debian |
| --- | --- | --- |
| Inspect provider conflict evidence before installation | `./DevRecipe_windows.ps1 -Preflight` | `bash ./DevRecipe_unix.bash --preflight` |
| Inspect evidence with no mutation | `./DevRecipe_windows.ps1 -Preflight -DryRun` | `bash ./DevRecipe_unix.bash --preflight --dry-run` |
| Approve each installation write interactively | `./DevRecipe_windows.ps1 -Review` | `bash ./DevRecipe_unix.bash --review` |
| Approve each confirmed removal write interactively | `./DevRecipe_windows.ps1 -Uninstall git -Yes -Review` | `bash ./DevRecipe_unix.bash --uninstall git --yes --review` |

`DevRecipe_unix.bash` detects macOS or Linux and selects the matching manifest.

`-Preflight` / `--preflight` may be combined with normal installation or dry run. On every platform, preflight runs by default for every installation plan, including normal installation, containers, review, and dry-run; the explicit option is equivalent and never runs a second scan. It does not run for validation, list, status, or removal. `-Review` / `--review` may be combined with normal installation or confirmed removal, but never with a dry run. Confirmed removal continues to use its separate exact-provider precondition checks. Both options validate the manifest first. Containers accept the same option for their own declared bundle.

## Conflict preflight

Preflight is a read-only audit for software already installed on the OS that may conflict with selected entries. It checks declared-provider inventories first, then bounded local OS installation evidence. When a declared provider lists the exact raw ID or Mise `name@version` specification, preflight removes that entry from the installation plan. This automatic skip emits no conflict trace or prompt: `Scoop installed-app inventory (scoop export)` means Scoop lists that exact package ID, not a filesystem location. The same rule applies to Homebrew, APT, Flatpak, and Mise. Provider presence does not prove DevRecipe ownership or provenance; it only prevents DevRecipe from submitting a duplicate exact installation. Remaining entries compare their raw ID with bounded local OS evidence, case-insensitively, using a Levenshtein similarity score. Evidence is reported at $90/100$ or higher. A report contains its query, source, scope, location, matched value, match reason, `similarity=<value>/100`, and `threshold=90/100`. To keep a conflict decision usable, each selected action renders at most three OS evidence records: installation/registration records first, then locations and launchers, then user/service/task metadata. Within a class, exact matches precede higher similarity matches. It does not prove package identity, provenance, ownership, or permission to remove anything.

The shipped collector is bounded and staged:

| Host | Sources currently queried |
| --- | --- |
| Windows | Scoop export; exact Mise installed-spec query; uninstall and App Paths registry views; AppX registrations; bounded approved application and Start Menu roots; service and scheduled-task names |
| macOS | Homebrew formula/cask lists; exact Mise installed-spec query; package-receipt IDs; names from `/Applications`, `~/Applications`, user application-support, launch-agent, and shortcut metadata |
| Ubuntu/Debian | `dpkg-query`; user Flatpak list; exact Mise installed-spec query; names from desktop-entry, `/opt`, `/usr/local`, XDG application-data, user-service, and user-configuration metadata |

Unavailable or inaccessible sources are reported as coverage notes, never as absence of conflict. Provider notes state whether the provider has not been bootstrapped or its inventory command failed; they are not repeated for each selected entry. Unix caches approved metadata roots once per preflight and scans independent roots concurrently; Windows likewise collects approved filesystem roots concurrently once for the selected audit. Windows groups incomplete filesystem checks into one coverage note per audit; it does not create a conflict or need a force/decline decision. Unix metadata scans are limited to depth two and 2,000 non-link filesystem names per approved root; user-home paths are redacted as `<home>`. On every host, preflight accepts a bounded generated label match when the raw ID's alphanumeric tokens begin the evidence label, with zero or more non-alphanumeric separators between tokens and a non-alphanumeric boundary (or the end) after the final token. This covers spaces, punctuation, and omitted separators—for example, `firefox-developer` matches `FirefoxDeveloper Edition`—but does not make `git` match `GitHub`. Windows additionally reads installation registry views, AppX registrations, bounded approved filesystem roots, service names, scheduled-task names, and applications resolvable as executables in the launching terminal's `PATH`. An AppX trace is a package registration: its location is the registered package installation path when Windows provides one, otherwise its package full name. `PATH` evidence accepts applications only—not PowerShell aliases, functions, or scripts—and records the resolved executable path. These are conflict evidence, not proof of package identity or ownership. Preflight does not scan application contents, follow links/reparse points, or send data off the machine.

Each remaining entry begins with a compact `--- PREFLIGHT CHECK: <query> ---` header. When a conflict is found in an interactive terminal, DevRecipe asks whether to continue with that exact declared action: type, provider, raw ID, and version. The default is no. A refusal removes only that detected action from the final plan; it does not install that raw ID. Each resolved decision is emitted as `decision=<force-or-decline> | application=<raw-id>`. Entries without preflight evidence remain in the plan.

The native Windows console and capable Unix terminals display an initially unchecked checklist. The visible window reserves four header rows and three menu-control rows, then uses the remaining terminal height for entries: `^ <count> more above` and `v <count> more below` indicate hidden entries. Up/Down moves through the full list and scrolls that window; Space toggles the current entry and `A` selects or deselects all. Move down past the final entry, or use Tab, to focus `[ Force selected ]` or `[ Cancel ]`; Left/Right changes the focused button. Enter confirms checked actions from the list or force button, while the cancel button and Escape decline every detected action. On Unix, `P` returns to the one-by-one prompt. Unix uses that prompt only when `tput` capabilities are unavailable or the terminal is too small for the checklist controls. In the one-by-one prompt, enter `A` or `all yes` to force the current and all remaining detected actions, or `D` or `all no` to decline the current and all remaining detected actions. In non-interactive execution, an unresolved conflict exits `3` before mutation. After a successful interactive preflight, DevRecipe prints the final filtered plan; a normal installation is labelled as an installation plan, never as a dry-run plan.

## Interactive review

Review displays a numbered checkpoint before each planned host write. Every checkpoint names exact command or target, privilege scope, source or target, and expected effect. On Windows, `-Review` first displays up to three conflict traces for each selected installation action and asks whether to force an exact declared installation; a forced action then receives its normal review checkpoint. Each selected Scoop package and Mise specification has its own checkpoint and provider invocation in review mode. Enter `y` or `yes` to approve that one action. On Windows, uppercase `A` approves the current checkpoint and every remaining review action; later checkpoint details are still displayed, but no further input is requested. Every other response, closed input, or a non-interactive terminal exits `3` before the current action runs. `-Yes` / `--yes` confirms a removal plan only; it never bypasses review.

Review covers provider bootstraps, package indexes, repositories/remotes, provider installs and removals, Windows Mise shim activation, Windows optional features, WSL configuration, UAC feature setup, and the optional Docker compatibility alias. It changes neither selected profiles nor raw IDs, provider selection, provider arguments, nor normal action order.

Review requires a real interactive terminal. It is deliberately rejected for list, status, validation, unconfirmed removal, and dry-run modes. A successful review invokes the same underlying operations as normal execution; it does not create a DevRecipe state record. At termination, its report counts approved, completed, and rejected checkpoints and identifies actions after a rejection as unreviewed.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Requested command completed. |
| `2` | Invalid command or manifest contract. |
| `3` | Unresolved non-interactive preflight conflict, refused preflight/review decision, or unavailable review terminal. |

Use [manual validation](manual-validation.md) to test either mode on a disposable host.