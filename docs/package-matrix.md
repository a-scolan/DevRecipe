# Package matrix

> Documentation type: reference. Use this page to find exact IDs and package coverage. Follow the [installation guide](installation.md) for commands and prerequisites.

For the product overview, scope, and first-run path, see [DevRecipe](../README.md). Use this page when you need exact provider IDs or the current shipped defaults for Windows.

## Manifest contract

`DevRecipe_windows.toml` uses a four-level layout. Categories make a reviewed manifest readable without changing selection or installation behavior.

| Manifest path | Meaning |
| --- | --- |
| `[profiles.<name>]` | Human-readable description of `default`, `ai_agents`, or `cloud`. |
| `[buckets]` | Declared Scoop buckets configured dynamically before package installation. |
| `[packages.<profile>.os.<category>]` | Windows package or desktop application installed via Scoop. |
| `[runtimes.<profile>.mise.<category>]` | Language runtime managed by Mise. |
| `[tools.<profile>.mise.<category>]` | Versioned CLI managed by Mise, including `npm:` and `ubi:` backends. |
| `[containers.default.os.<category>]` | Optional container-runtime bundle, consumed only by `-Containers` after manifest validation. |

`default` is always selected. Add `ai-agents` or `cloud` with `-Profile ai-agents,cloud` on Windows. The recipe normalizes the command-line spelling `ai-agents` to the TOML key `ai_agents`.

A non-empty version asks the recipe to install the entry. `"latest"` tracks the provider's current package. Optional runtimes are represented by commented-out `"latest"` entries in `[runtimes.default.mise.optional]`; uncomment an entry to opt in.

## Provider documentation

Provider IDs are local to their provider. Find an ID in its provider catalogue; do not substitute an executable name, an application display name, or an ID from another provider. Provider configuration, activation, updates, troubleshooting, and recovery remain provider responsibilities. DevRecipe deliberately does not provide provider-wide update, cleanup, or rollback commands.

When selected entries include Mise runtimes or tools, DevRecipe configures conflict-free default runtimes globally via `mise use -g`, runs `mise reshim`, adds `%LOCALAPPDATA%\mise\shims` and `%USERPROFILE%\scoop\shims` to the signed-in user's `PATH` for `cmd.exe` and new processes, configures `AutoRun` in `HKCU:\Software\Microsoft\Command Processor` (`%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd`) to guarantee shim precedence for `cmd.exe` sub-processes, and adds `mise activate <shell> --shims` hooks for compatible shells available on the host: PowerShell, Nushell, Bash, Zsh, Fish, Elvish, and Xonsh. Note that Windows merges `System PATH` ahead of `User PATH` for GUI applications; desktop launchers (like VS Code) inherit system-wide binaries if present unless launched from an initialized shell. Mise has no `cmd.exe` activation shell, so the user `PATH` entry and `AutoRun` helper are the supported fallbacks. Existing terminals and VS Code processes keep their inherited `PATH`; open a new terminal after installation.

| Provider | Used by DevRecipe for | Official documentation |
| --- | --- | --- |
| Scoop | Windows packages | [Quick Start](https://github.com/ScoopInstaller/Scoop/wiki/Quick-Start) · [commands](https://github.com/ScoopInstaller/Scoop/wiki/Commands) |
| Mise | Runtimes and versioned CLIs | [Getting Started](https://mise.jdx.dev/getting-started) · [Dev Tools](https://mise.jdx.dev/dev-tools/) |

## Current shipped coverage

These tables describe the entries shipped in `DevRecipe_windows.toml`. Users can customize the manifest independently. DevRecipe sends each ID to Scoop or Mise as written.

## Core tools

| Capability | Windows declaration |
| --- | --- |
| Source control | Scoop `git` |
| Terminal | Scoop `alacritty` |
| Structured shell | Scoop `nushell` |
| Runtime manager | Scoop `mise` |
| Compiler and build tools | Scoop `gcc`, `make` |
| POSIX utilities | Scoop `coreutils`, `sed`, `gawk` |
| DNS and network tools | Scoop `bind-tooling`, `nmap`, `netcat` |
| Local development web server | Scoop `nginx` |
| Search and navigation | Scoop `ripgrep`, `fd`, `bat`, `fzf` |
| HTTP client | Scoop `curl` |
| Archive tool | Scoop `7zip` |
| GitHub tooling | Scoop `gh` |

## Default database clients

The default profile installs both DBeaver and the following command-line clients. It does not start database servers or create local data stores.

| Client | Windows declaration |
| --- | --- |
| SQLite | Scoop `sqlite` |
| PostgreSQL | Scoop `postgresql` |
| MySQL / MariaDB | Scoop `mysql` |
| Redis | Scoop `redis` |

## Runtimes managed by Mise

| Runtime | Windows declaration |
| --- | --- |
| Node.js | `node = "latest"` |
| pnpm | `pnpm = "latest"` |
| Python | `python = "latest"` |
| Java | `java = "latest"` |
| Optional Go, Rust, Bun, Deno, Ruby, PHP | Commented-out `"latest"` entries; not installed |

## Desktop and development applications

| Capability | Windows declaration |
| --- | --- |
| Code editor | Scoop `vscode` |
| Database client | Scoop `dbeaver` |
| Diagram editor | Scoop `yed` |
| Knowledge bases | Scoop `logseq`, `obsidian` |
| Scientific publishing | Scoop `quarto` |
| Media player | Scoop `vlc` |
| API client | Scoop `bruno` |
| LDAP client | Scoop `apache-directory-studio` |
| Developer browser | Scoop `firefox-developer` |
| Text expander | Scoop `espanso` |
| Lightweight editor | Scoop `notepadplusplus` |
| Terminal multiplexer GUI | Scoop `mobaxterm` |
| Diff and merge tool | Scoop `meld` |
| Platform utilities | Scoop `powertoys` |

## `ai-agents` profile

This optional profile assumes the default Node.js runtime. It keeps GUI and terminal AI tools out of the daily baseline.

| Capability | Windows declaration |
| --- | --- |
| GitHub Copilot CLI | Mise `"npm:@github/copilot"` |
| Claude Desktop | Scoop `claude` (from Scoop Extras) |
| Claude Code | Mise `"npm:@anthropic-ai/claude-code"` |
| Gemini CLI | Mise `"npm:@google/gemini-cli"` |
| Codex CLI | Mise `"npm:@openai/codex"` |

On Windows, `claude` is a Scoop Extras ID. Declaring `extras` under `[buckets]` ensures the required bucket is configured automatically.

## `cloud` profile

Cloud tools are Mise-managed in the shipped manifest. Installing this profile does not authenticate to an account, create a Kubernetes cluster, or select a cloud subscription.

| Capability | Mise declaration |
| --- | --- |
| AWS CLI | `awscli = "latest"` |
| Azure CLI | `azure-cli = "latest"` |
| Google Cloud CLI | `gcloud = "latest"` |
| Kubernetes client | `kubectl = "latest"` |
| Helm | `helm = "latest"` |
| OpenTofu | `opentofu = "latest"` |

## Containers

Container packages remain separate because an engine can need host virtualization support. The normal base installation does not run it. The recipe consumes the bundle only with `-Containers`.

| Component | Windows declaration |
| --- | --- |
| Podman engine | `[containers.default.os.engine]` `podman`; existing Podman machine or WSL 2 Podman distribution preserved, then ready WSL 2, then ready Hyper-V |
| Podman Desktop | `[containers.default.os.engine]` `podman-desktop` from Scoop Extras |
| Compose provider | `[containers.default.os.compatibility]` `docker-compose`; invoked through `podman compose` |
| Kubernetes CLI | `cloud` profile via Mise; client only, no local cluster enabled |
| Recommended workflow | Run `DevRecipe_windows.ps1 -Containers`; follow the [Windows provider policy](container-provider-policy.md) |

For exact setup and verification, see [Install DevRecipe](installation.md#install-containers-separately). For the Windows tie-break and fallback rules, see [Windows Podman machine provider policy](container-provider-policy.md).
