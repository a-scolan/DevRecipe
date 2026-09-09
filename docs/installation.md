# Install DevRecipe

> **Documentation type:** how-to guide. Use this page to provision one supported workstation from a reviewed manifest.

DevRecipe validates a manifest before it resolves entries, bootstraps a provider, or mutates the host. Review the relevant manifest before running any install command.

## Before you start

- **Windows:** run the recipe from a normal PowerShell session. `-Containers` requests UAC only when Windows virtualisation features need changing.
- **macOS:** Homebrew or build tooling can require Apple's Xcode Command Line Tools. Install or approve them separately when prompted; DevRecipe does not provision them.

## Inspect before installation

Run these commands from the repository root. They do not call package providers.

| Goal | Windows | macOS / Ubuntu-Debian |
| --- | --- | --- |
| Validate TOML | `./DevRecipe_windows.ps1 -Validate` | `bash ./DevRecipe_unix.bash --validate` |
| List manifest entries | `./DevRecipe_windows.ps1 -List` | `bash ./DevRecipe_unix.bash --list` |
| See planned bootstrap and install commands | `./DevRecipe_windows.ps1 -DryRun` | `bash ./DevRecipe_unix.bash --dry-run` |

`DevRecipe_unix.bash` detects macOS or Linux and selects the matching manifest. Validation and list do not call providers. Every platform runs its read-only default preflight audit before rendering an installation or dry-run plan. It checks provider inventories and local OS installation evidence for software that may conflict with selected entries. A validation failure exits before provider calls or file creation.

The dry-run output can include a remote provider bootstrap: Scoop on Windows, Homebrew on macOS, and Mise on Linux. On Linux it can also include `sudo apt update`, user-scoped Flathub setup, or Anthropic's signed APT source when `claude-desktop` is selected. Treat these as review and approval boundaries.

## Resolve conflicts or approve each write

Every platform runs the read-only preflight audit before normal installation, containers, review, and dry-run. If it shows local conflict evidence in an interactive terminal, choose whether the exact declared entry should be forced or declined; declining it leaves other entries in the plan. An unresolved conflict in non-interactive execution stops before mutation.

Use review only when a person must approve every host write:

| Host | Command |
| --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Review` |
| macOS / Ubuntu-Debian | `bash ./DevRecipe_unix.bash --review` |

The [preflight and review reference](preflight-and-review.md) is the source of truth for explicit `-Preflight` / `--preflight`, evidence sources, terminal controls, option restrictions, and exit codes.

## Install the selected baseline

| Host | Command | Provider route |
| --- | --- | --- |
| Windows | `./DevRecipe_windows.ps1` | Scoop, then Mise |
| macOS | `bash ./DevRecipe_unix.bash` | Homebrew, then Mise |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash` | APT, user Flatpak, then Mise |

Linux APT operations require `sudo`. Windows base provisioning is user-scoped after Scoop is available; it does not change virtualisation settings unless `-Containers` is selected. Managed-device policies, proxies, allowlists, code-signing requirements, and denied elevation remain authoritative.

The recipes send selected raw IDs to their declared provider. They do not infer a package from `PATH`, an executable name, an application display name, or an ID from another provider.

On Windows, Mise is installed through Scoop. Because the current Scoop manifest does not add Mise's tool-shims directory to `PATH`, DevRecipe runs `mise reshim`, adds `%LOCALAPPDATA%\mise\shims` to the signed-in user's `PATH` for `cmd.exe` and new processes, and adds Mise shim activation commands to startup files for compatible shells available on the host: PowerShell, Nushell, Bash, Zsh, Fish, Elvish, and Xonsh. Mise does not provide a `cmd.exe` activation shell; the persistent user `PATH` entry is the supported fallback. Each other startup hook calls `mise activate <shell> --shims`, so Scoop still owns the `mise` executable path and Mise owns the shims path calculation at shell startup. Open a new terminal after installation before running commands installed through Mise; DevRecipe does not restart existing terminals or VS Code.

For package discovery, other Mise activation modes, provider updates, or provider-specific recovery, use the official links in [provider documentation](package-matrix.md#provider-documentation). DevRecipe does not manage those provider-wide operations.

The manifest defines only what DevRecipe asks a provider to install. Customise it for your workstation, then configure each installed application yourself.

## Add optional profiles

`default` is always selected. Add optional capabilities when needed:

| Profile | Windows | macOS | Ubuntu/Debian |
| --- | --- | --- | --- |
| AI agents and Claude Desktop | `./DevRecipe_windows.ps1 -Profile ai-agents` | `bash ./DevRecipe_unix.bash --profile ai-agents` | `bash ./DevRecipe_unix.bash --profile ai-agents` |
| Cloud CLIs | `./DevRecipe_windows.ps1 -Profile cloud` | `bash ./DevRecipe_unix.bash --profile cloud` | `bash ./DevRecipe_unix.bash --profile cloud` |
| Both | `./DevRecipe_windows.ps1 -Profile ai-agents,cloud` | `bash ./DevRecipe_unix.bash --profile ai-agents,cloud` | `bash ./DevRecipe_unix.bash --profile ai-agents,cloud` |

`ai-agents` maps to the TOML profile key `ai_agents`. Exact declarations are listed in the [package matrix](package-matrix.md).

## Install a container runtime deliberately

Containers are separate from the base workstation install. Each command below executes only the container bundle declared for that host.

| Host | Command | Boundary |
| --- | --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Containers` | Scoop Podman bundle; integrated UAC/WSL/Hyper-V preparation when required |
| macOS | `bash ./DevRecipe_unix.bash --containers` | Homebrew Podman; creates a machine only when none exists |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash --containers` | APT Podman rootless bundle; no machine or service |

On Windows, `-ContainerProvider WSL` or `-ContainerProvider HyperV` requests a provider for a new environment; the default `Auto` favours ready WSL 2. Add `-EnableDockerAlias` only when an existing script requires `docker ...` to forward to Podman. Existing Podman machines and WSL distributions are preserved, so create a new Windows machine deliberately after installation with the command printed by the recipe.

See [container provider policy](container-provider-policy.md) before changing Windows virtualisation features.

## Verify the result

Use the matching provider-status command after installation:

| Host | Command |
| --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Status` |
| macOS | `bash ./DevRecipe_unix.bash --status` |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash --status` |

`installed` means that the declared provider lists the exact raw ID. It is provider evidence, not proof of DevRecipe ownership. See the [status and removal reference](status-and-removal.md) for status sources and removal limits.
