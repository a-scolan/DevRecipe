# Status and narrow removal reference

> **Documentation type:** reference. This page defines DevRecipe's read-only status and exact-ID removal behaviour.

## Commands

| Purpose | Windows | macOS / Ubuntu-Debian |
| --- | --- | --- |
| Validate manifest only | `-Validate` | `--validate` |
| List manifest only | `-List` | `--list` |
| Show provider-native status | `-Status` | `--status` |
| Print install plan | `-DryRun` | `--dry-run` |
| Inspect selected-provider conflict evidence | `-Preflight` | `--preflight` |
| Require per-action host-write approval | `-Review` | `--review` |
| Print removal plan | `-Uninstall <id>` | `--uninstall <id>` |
| Confirm removal | `-Uninstall <id> -Yes` | `--uninstall <id> --yes` |

Choose only one primary mode. Confirmation requires an uninstall request. Manifest validation occurs before every supported mode.

Preflight is valid only for installation and dry run. Review is valid only for installation and confirmed removal; it rejects dry run and non-interactive terminals. The [preflight and review reference](preflight-and-review.md) defines evidence, approval, and exit-code semantics.

## Provider status sources

| Host | Declared provider | Exact inventory source |
| --- | --- | --- |
| Windows | Scoop packages | `scoop export` |
| Windows | Mise runtimes/tools | `mise ls --installed <name>@<version>` |
| macOS | Homebrew formulae | `brew list --formula` |
| macOS | Homebrew casks | `brew list --cask` |
| macOS | Mise runtimes/tools | `mise ls --installed <name>@<version>` |
| Ubuntu/Debian | APT packages | `dpkg-query -W` |
| Ubuntu/Debian | User Flatpak applications | `flatpak list --user --app --columns=app` |
| Ubuntu/Debian | Mise runtimes/tools | `mise ls --installed <name>@<version>` |

`installed` means the provider returned an exact raw ID/specification. `missing` means its accessible inventory lacks that exact entry. `unavailable` means DevRecipe could not obtain the relevant provider inventory.

A result is not provenance. It never proves that DevRecipe installed, owns, may update, or may remove the item. A system Flatpak record does not satisfy the user-scoped Flatpak declaration.

## Installation boundary

Normal installation forwards selected non-empty raw IDs to their declared provider. It does not use status to infer ownership or to transform IDs.

Mise installation uses exact `name@version` specifications and does not create or alter `~/.config/mise/config.toml` or invoke `mise use --global`.

## Removal eligibility

An uninstall request is eligible only when all conditions hold:

1. The requested ID is declared exactly once by the selected profiles.
2. Its declared provider is available.
3. The provider currently lists the exact ID or Mise specification.
4. Every requested item passes this preflight before any removal starts.
5. The user supplies `-Yes` / `--yes` after seeing the plan.

A failed preflight leaves every requested item untouched. Select optional profiles explicitly when removing their entries.

## Removal commands

| Provider | Exact mutation |
| --- | --- |
| Scoop | `scoop uninstall <id>` |
| Homebrew formula | `brew uninstall <id>` |
| Homebrew cask | `brew uninstall --cask <id>` |
| APT | `sudo apt remove -y <id>` |
| User Flatpak | `flatpak uninstall --user --no-related --keep-ref -y <id>` |
| Mise | `mise uninstall <name>@<version>` |

Mise runtime/tool removals run before package-provider removals, so removing a package-provider `mise` package cannot prevent an already approved Mise removal.

DevRecipe never performs provider-wide update or cleanup, `autoremove`, `purge`, Homebrew `--zap`/`--force`, Scoop `-p`, Flatpak data deletion, remote deletion, bootstrap removal, configuration removal, container deletion, or operating-system feature cleanup.