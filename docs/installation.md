# Install DevRecipe

> Documentation type: how-to guide. Use this page to provision one supported host from a reviewed manifest.

Read the platform manifest before you run an installation command. DevRecipe validates the manifest, runs a read-only preflight, and then sends selected identifiers to their declared providers.

## Before you start

| Host | Requirement |
| --- | --- |
| Windows | Run from a normal PowerShell session. Base installation does not request UAC. Container setup can request UAC. |
| macOS | Homebrew or build tools can require Xcode Command Line Tools. DevRecipe does not install them. |
| Ubuntu/Debian | APT operations require `sudo`. The recipe does not support other Linux distributions. |

Managed-device policy, proxy rules, allowlists, code-signing rules, and denied elevation remain authoritative.

## Inspect the plan

Run these commands from the repository root:

| Goal | Windows | macOS or Ubuntu/Debian |
| --- | --- | --- |
| Validate TOML | `./DevRecipe_windows.ps1 -Validate` | `bash ./DevRecipe_unix.bash --validate` |
| List declarations | `./DevRecipe_windows.ps1 -List` | `bash ./DevRecipe_unix.bash --list` |
| Preview writes | `./DevRecipe_windows.ps1 -DryRun` | `bash ./DevRecipe_unix.bash --dry-run` |

Validation and list mode do not call providers. Dry run does not mutate the host. It runs the same read-only preflight as installation and can query provider inventories and bounded local evidence.

Preflight evidence means that a possible conflict exists. It does not prove that DevRecipe installed or owns the software. In an interactive terminal, choose whether to force or decline each detected entry. In a non-interactive terminal, an unresolved conflict returns `3` and stops before mutation.

## Install the baseline

| Host | Command | Provider route |
| --- | --- | --- |
| Windows | `./DevRecipe_windows.ps1` | Scoop, then Mise |
| macOS | `bash ./DevRecipe_unix.bash` | Homebrew, then Mise |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash` | APT, user Flatpak, then Mise |

The recipes use exact provider IDs. They do not infer an entry from `PATH`, an executable name, an application display name, or another provider.

### Windows Mise and Scoop activation

When the selection includes Mise entries, DevRecipe runs `mise reshim`, adds `%LOCALAPPDATA%\mise\shims` and `%USERPROFILE%\scoop\shims` to the signed-in user's `PATH` for `cmd.exe` and new processes, configures a command processor `AutoRun` helper in `HKCU:\Software\Microsoft\Command Processor` (`%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd`) to enforce shim precedence for `cmd.exe` sub-processes, and adds shell startup hooks when those shells are available. It does not change the system `PATH`, create `~/.config/mise/config.toml`, or restart VS Code.

The supported hook locations are:

- PowerShell: the user profiles under `Documents\WindowsPowerShell` and `Documents\PowerShell`
- Bash: `.bash_profile` and `.bashrc`
- Zsh: `.zprofile` and `.zshrc`
- Fish: `%APPDATA%\fish\config.fish`
- Nushell: `%APPDATA%\nushell\env.nu` and `config.nu`
- Elvish: `%APPDATA%\elvish\rc.elv`
- Xonsh: `.xonshrc`

Open a new terminal or VS Code process before you run a Mise-managed command. Provider configuration, package discovery, updates, and recovery remain provider responsibilities. See [provider documentation](package-matrix.md#provider-documentation).

## Add an optional profile

`default` is always selected. Add profiles when the request needs them:

| Need | Windows | macOS or Ubuntu/Debian |
| --- | --- | --- |
| AI command-line tools and desktop clients | `./DevRecipe_windows.ps1 -Profile ai-agents` | `bash ./DevRecipe_unix.bash --profile ai-agents` |
| Cloud and infrastructure CLIs | `./DevRecipe_windows.ps1 -Profile cloud` | `bash ./DevRecipe_unix.bash --profile cloud` |
| Both profiles | `./DevRecipe_windows.ps1 -Profile ai-agents,cloud` | `bash ./DevRecipe_unix.bash --profile ai-agents,cloud` |

On Linux, `--profile ai-agents` adds Anthropic's signed APT source before it installs the `claude-desktop` beta package. This is a system change and requires `sudo`. On Windows, the `claude` entry comes from Scoop Extras. DevRecipe's normal profile installation does not add arbitrary Scoop buckets, so an approved Extras bucket must already be available.

The profile key in TOML is `ai_agents`. The [package matrix](package-matrix.md) lists the exact declarations.

## Install containers separately

Container setup runs only when you select it. It does not install the normal baseline.

| Host | Command | Scope |
| --- | --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Containers` | Scoop Podman bundle and optional WSL 2 or Hyper-V feature setup |
| macOS | `bash ./DevRecipe_unix.bash --containers` | Homebrew Podman and a machine only when none exists |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash --containers` | APT Podman rootless bundle, without a machine or service |

Windows uses `-ContainerProvider WSL` or `-ContainerProvider HyperV` only when selecting a provider for a new environment. `Auto` favors ready WSL 2. Add `-EnableDockerAlias` only when an existing script needs `docker ...` to forward to Podman. Existing Podman machines and WSL distributions are preserved.

See the [container provider policy](container-provider-policy.md) before changing Windows virtualization features.

## Verify the result

Run status with the same selected profiles:

| Host | Command |
| --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Status` |
| macOS or Ubuntu/Debian | `bash ./DevRecipe_unix.bash --status` |

`installed` means that the provider lists the exact ID or Mise specification. It is not installation provenance. See the [status and removal reference](status-and-removal.md).
