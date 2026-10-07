# Install DevRecipe

> Documentation type: how-to guide. Use this page to provision Windows developer workstations from a reviewed manifest.

Read the platform manifest `DevRecipe_windows.toml` before you run an installation command. DevRecipe validates the manifest, runs a read-only preflight, and then sends selected identifiers to their declared providers (Scoop and Mise).

## Before you start

Run from a normal Windows PowerShell session. Base installation does not request UAC. Container setup can request UAC when virtualization features need activation.

Managed-device policy, proxy rules, allowlists, code-signing rules, and denied elevation remain authoritative.

## Inspect the plan

Run these commands from the repository root:

| Goal | Command |
| --- | --- |
| Validate TOML | `./DevRecipe_windows.ps1 -Validate` |
| List declarations | `./DevRecipe_windows.ps1 -List` |
| Preview writes | `./DevRecipe_windows.ps1 -DryRun` |

Validation and list mode do not call providers. Dry run does not mutate the host. It runs the same read-only preflight as installation and can query provider inventories and bounded local evidence.

Preflight evidence means that a possible conflict exists. It does not prove that DevRecipe installed or owns the software. In an interactive terminal, choose whether to force or decline each detected entry. In a non-interactive terminal, an unresolved conflict returns `3` and stops before mutation.

## Install the baseline

Run:

```powershell
./DevRecipe_windows.ps1
```

The recipe uses exact provider IDs. It does not infer an entry from `PATH`, an executable name, an application display name, or another provider.

During execution, DevRecipe displays a unified progress bar across all Scoop and Mise operations, suppresses low-level provider noise on standard output, saves full execution traces to a timestamped file under `logs/`, and outputs a structured component recap upon completion.

### Windows Mise and Scoop activation

Each approved standard Windows installation runs `scoop update` to update Scoop itself and refresh its catalogs.
This also runs when every selected component is already installed.
Git is required for Scoop self-update and additional catalogs. If Git is absent, DevRecipe installs only an approved selected Git entry first.
An unavailable prerequisite or failed update stops execution with an error.
DevRecipe compares Scoop and catalog Git revisions with their remote branches after the refresh.
Held updates, local changes, stale catalogs, and failed remote checks stop execution before package update decisions.

DevRecipe checks installed Scoop-managed Mise on each such run, even when no runtime needs installation.
It applies available Mise updates through Scoop, not `mise self-update`.
Absent Mise is installed only when selected approved work requires it.
If another Mise executable shadows Scoop on `PATH`, DevRecipe stops and reports the conflicting location.

Installed Scoop packages declared as `latest` in the selected profiles receive available updates by exact ID.
Unrelated installed packages are not updated. Explicit package versions remain fixed.
Mise also resolves partial versions such as `22`, explicit prefixes such as `prefix:22`, and backend-supported aliases such as `lts`.
The original request remains unchanged. `node@22` never becomes unrestricted `node@latest`.
NPM ranges such as `^22`, `~22`, and `22.*` are not supported as general Mise command arguments in this route.
Use a concrete version or a supported Mise selector instead.
Local paths, `system`, source references, and subtraction scopes have no maintenance policy here and are rejected before writes.

DevRecipe retains older Mise runtime versions and does not change global or project version selection.
An installed latest version can differ from the active version.
Review approves each write. Dry run shows provisional update actions without refreshing catalogs or changing the host.
Validation, list, status, removal, and the separate container route do not perform this maintenance.
Native updates are not transactional. Earlier successful actions remain in place if a later operation fails.

When the approved selection includes Mise entries, DevRecipe generates shims and configures user shell integration.
It adds `%LOCALAPPDATA%\mise\shims` and `%USERPROFILE%\scoop\shims` to the user's `PATH` for `cmd.exe` and new processes.
It configures `%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd` through `HKCU:\Software\Microsoft\Command Processor\AutoRun` to enforce shim precedence.
It also adds startup hooks for available shells.
It does not change the system `PATH` or restart VS Code.

When approved default language runtimes (`[runtimes.default.mise.*]`, such as `node` or `python`) are installed on a clean machine without pre-existing host installations or active versions, DevRecipe automatically activates them globally via `mise use -g` before regenerating shims. If preflight conflict detection or system discovery detects an existing installation on the host, DevRecipe skips global activation for that runtime to prevent superseding the existing environment.

### Windows PATH precedence and GUI limitations

Under Windows, the operating system constructs process environments by merging Machine (`HKLM`) `PATH` before User (`HKCU`) `PATH`. Because DevRecipe operates strictly in user space without requiring administrator privileges, it installs Mise and Scoop shims into the User `PATH` (`HKCU:\Environment\Path`).

DevRecipe guarantees shim precedence for:
- Interactive shells (PowerShell, Nushell, Bash, Zsh, Fish, Elvish, Xonsh) through profile hooks that prepend shims in memory.
- `cmd.exe` sub-processes through `HKCU:\Software\Microsoft\Command Processor\AutoRun`.

However, desktop applications and GUI launchers (such as VS Code, Windows Terminal, or IDEs launched directly from the Start Menu or Explorer) inherit the default Windows process environment where `System PATH` takes precedence over `User PATH`. If a tool is installed machine-wide (for example, a system-level Python or Node.js under `C:\Program Files`), the machine-level binary will shadow the user-space shim in those GUI contexts.

To ensure GUI applications and IDEs use DevRecipe runtimes:
- Launch your editor from an initialized terminal (for example, `code .` from PowerShell).
- Or configure your editor's terminal to use a supported shell with profile execution enabled.

After a Mise provider update or approved Node work, `mise reshim --force` rebuilds Mise-owned shims.
Node work requires Mise 2026.10.1 or later, which contains the fix for [jdx/mise#13901](https://github.com/jdx/mise/issues/13901).
DevRecipe tests IPC, communication between a parent and child process, through the absolute user Node shim.
The test must complete within five seconds and reports the active Node executable and version separately from the installed version.
If the shim cannot select Node or the exchange fails, execution returns an error without changing version selection.

The supported hook locations are:

- PowerShell: the user profiles under `Documents\WindowsPowerShell` and `Documents\PowerShell`
- Bash: `.bash_profile` and `.bashrc`
- Zsh: `.zprofile` and `.zshrc`
- Fish: `%APPDATA%\fish\config.fish`
- Nushell: `%APPDATA%\nushell\env.nu` and `config.nu`
- Elvish: `%APPDATA%\elvish\rc.elv`
- Xonsh: `.xonshrc`

Open a new terminal or VS Code process before you run a Mise-managed command.
Provider configuration, package discovery, and recovery remain provider responsibilities.
See [provider documentation](package-matrix.md#provider-documentation).

## Add an optional profile

`default` is always selected. Add profiles when the request needs them:

| Need | Command |
| --- | --- |
| AI command-line tools and desktop clients | `./DevRecipe_windows.ps1 -Profile ai-agents` |
| Cloud and infrastructure CLIs | `./DevRecipe_windows.ps1 -Profile cloud` |
| Both profiles | `./DevRecipe_windows.ps1 -Profile ai-agents,cloud` |

On Windows, the `claude` entry comes from Scoop Extras. DevRecipe's normal profile installation dynamically ensures all buckets declared under `[buckets]` are configured.

The profile key in TOML is `ai_agents`. The [package matrix](package-matrix.md) lists the exact declarations.

## Install containers separately

Container setup runs only when you select it. It does not install the normal baseline:

```powershell
./DevRecipe_windows.ps1 -Containers
```

Windows uses `-ContainerProvider WSL` or `-ContainerProvider HyperV` only when selecting a provider for a new environment. `Auto` favors ready WSL 2. Add `-EnableDockerAlias` only when an existing script needs `docker ...` to forward to Podman. Existing Podman machines and WSL distributions are preserved.

See the [container provider policy](container-provider-policy.md) before changing Windows virtualization features.

## Verify the result

Run status with the same selected profiles:

```powershell
./DevRecipe_windows.ps1 -Status
```

`installed` means that the provider lists the exact ID or Mise specification. It is not installation provenance. See the [status and removal reference](status-and-removal.md).
