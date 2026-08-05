# DevRecipe

DevRecipe is a reviewable, user-space-first workstation bootstrapper for Windows, macOS, and Ubuntu/Debian. Each platform manifest declares provider-specific package IDs; its recipe validates the manifest, creates an installation plan, installs selected tools and runtimes, and provides provider-native status and precise removal commands.

## Who it helps

DevRecipe helps developers provision or rebuild a supported personal workstation from a reviewed, versioned baseline. It also gives teams a readable starting point for common tools and runtimes.

It reduces repeated package setup and userspace configuration (environment variables, etc.) and delegates versioned runtimes and CLIs to Mise.

## Quick start

Run the shipped `default` profile:

### Windows (PowerShell)

```powershell
$ErrorActionPreference = "Stop"
git clone https://github.com/a-scolan/DevRecipe DevRecipe
Set-Location DevRecipe
.\DevRecipe_windows.ps1
```

### macOS or Linux (Bash)

```bash
git clone https://github.com/a-scolan/DevRecipe DevRecipe && cd DevRecipe && bash DevRecipe_unix.bash
```

The commands install the non-empty versions `default` profile entries. To choose packages, add optional profiles, or inspect the plan first, use [Start and customise DevRecipe](docs/quick-start.md).

## Inspect or customise

After cloning the repository, run these commands from its root to review the manifest and plan before installation:

| Host | Validate | List declared entries | Dry-run plan | Install |
| --- | --- | --- | --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Validate` | `./DevRecipe_windows.ps1 -List` | `./DevRecipe_windows.ps1 -DryRun` | `./DevRecipe_windows.ps1` |
| macOS | `bash ./DevRecipe_unix.bash --validate` | `bash ./DevRecipe_unix.bash --list` | `bash ./DevRecipe_unix.bash --dry-run` | `bash ./DevRecipe_unix.bash` |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash --validate` | `bash ./DevRecipe_unix.bash --list` | `bash ./DevRecipe_unix.bash --dry-run` | `bash ./DevRecipe_unix.bash` |

`DevRecipe_unix.bash` detects macOS or Linux and selects the matching Unix manifest. `default` is always selected; add `ai-agents` and `cloud` with `-Profile ai-agents,cloud` on Windows or `--profile ai-agents,cloud` on macOS/Linux.

Installation and dry-run include automatic read-only preflight: an audit of provider inventories and local OS installation evidence for software that may conflict with selected entries. Use `-Review` / `--review` to approve each host write in a real terminal. See [preflight and review](docs/preflight-and-review.md) for audit sources, controls, and exit behaviour.

## How it works

1. Review or edit the platform TOML manifest. It contains provider-local package IDs, not executable-name guesses.
2. Validate, list, and dry-run the selected profile.
3. Run the matching recipe. It audits the OS for potentially conflicting installed software, then sends each remaining raw ID to its declared provider.
4. Use provider-native status to compare the declaration with provider inventories, or use the explicit removal plan for one declared ID.

## What the recipes do

- **Windows:** Scoop packages and Mise runtimes/tools.
- **macOS:** Homebrew formulae/casks and Mise runtimes/tools.
- **Ubuntu/Debian:** APT packages, user-scoped Flatpak applications, and Mise runtimes/tools.
- **Containers:** opt-in runtime bundle. Add `-Containers` on Windows or `--containers` on macOS/Ubuntu-Debian; the matching public recipe installs the declared Podman bundle.

`-DryRun` / `--dry-run` shows the installation plan and provider bootstrap boundaries before execution.

## Provider documentation

Use the official provider documentation to find package IDs, configure or activate a provider, update provider-managed software, and recover from provider-specific failures.

| Provider | DevRecipe route | Official documentation |
| --- | --- | --- |
| Scoop | Windows packages | [Quick Start](https://github.com/ScoopInstaller/Scoop/wiki/Quick-Start) · [commands](https://github.com/ScoopInstaller/Scoop/wiki/Commands) |
| Homebrew | macOS formulae and casks | [installation](https://docs.brew.sh/Installation) · [command reference](https://docs.brew.sh/Manpage) |
| APT | Ubuntu/Debian packages | [APT User's Guide](https://www.debian.org/doc/manuals/apt-guide/) |
| Flatpak | Ubuntu/Debian user-scoped desktop applications | [Using Flatpak](https://docs.flatpak.org/en/latest/using-flatpak.html) |
| Mise | Runtimes and versioned CLIs on every supported host | [Getting Started](https://mise.jdx.dev/getting-started) · [Dev Tools](https://mise.jdx.dev/dev-tools/) |

## See what is installed

Use provider-native status, not executable-name guesses:

| Host | Command |
| --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Status` |
| macOS | `bash ./DevRecipe_unix.bash --status` |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash --status` |

Status reports exact raw IDs known by the declared provider.

## Remove one declared item

Removal targets one declared provider ID:

1. Select an exact ID declared by the selected profiles.
2. Read the plan.
3. Repeat with explicit confirmation only if removal is desired.

| Host | Plan | Confirm |
| --- | --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Uninstall git` | `./DevRecipe_windows.ps1 -Uninstall git -Yes` |
| macOS | `bash ./DevRecipe_unix.bash --uninstall git` | `bash ./DevRecipe_unix.bash --uninstall git --yes` |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash --uninstall git` | `bash ./DevRecipe_unix.bash --uninstall git --yes` |

Only exact provider IDs are eligible. See the [status and removal reference](docs/status-and-removal.md) for eligibility and provider commands.

## Documentation

| Need | Read |
| --- | --- |
| First run or first manifest change | [Start and customise DevRecipe](docs/quick-start.md) — tutorial |
| Provision one host | [Installation guide](docs/installation.md) — how-to |
| Change a manifest, inspect status, or remove one item | [User guide](docs/user-guide.md) — how-to |
| Find raw package IDs or upstream provider help | [Package matrix](docs/package-matrix.md#provider-documentation) — reference |
| Inspect conflict evidence or approve every write | [Preflight and review reference](docs/preflight-and-review.md) — advanced reference |
| Exact status and removal semantics | [Status and removal reference](docs/status-and-removal.md) — reference |
| Windows Podman provider policy | [Container provider policy](docs/container-provider-policy.md) — explanation |
| Enterprise and privilege boundaries | [Enterprise governance](docs/enterprise-governance.md) |
| Manual checks | [Manual validation](docs/manual-validation.md) |
| Local test gates | [Acceptance checks](tests/acceptance/README.md) |
| Scope and deliberate non-goals | [Roadmap](docs/roadmap.md) |

## Scope and limits

DevRecipe focuses on turning a reviewed manifest into repeatable provider operations. Application configuration, credentials, data, service management, and provider-wide lifecycle work remain with the relevant application or package provider. Status reports provider inventory rather than installation provenance, and removal operates only on confirmed exact IDs.

Use the [provider documentation](#provider-documentation), [status and removal reference](docs/status-and-removal.md), and [roadmap](docs/roadmap.md) when you need those boundaries in detail.

## Supported hosts

Windows uses Scoop; macOS uses Homebrew; Linux support is the implemented Ubuntu/Debian APT plus Flatpak route. Fedora, RHEL, Arch, and Pacman are not currently supported by the base recipe.
