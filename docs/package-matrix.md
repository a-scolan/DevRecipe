# Package Matrix

> **Documentation type:** reference. This page names package identifiers and platform coverage; follow the [installation guide](installation.md) for commands and prerequisites.

For the product overview, scope, and first-run path, see [DevRecipe](../README.md). Use this page when you need exact provider IDs or the current shipped defaults for a host.

Each table lists the current shipped defaults for the three supported host variants. An em dash does not imply an equivalent package exists. It means that the operating system supplies the item, the item is intentionally platform-specific, or the current manifest does not declare it.

## Manifest contract

All manifests use the same four-level layout. Categories make a reviewed manifest readable without changing selection or installation behaviour.

| Manifest path | Meaning |
| --- | --- |
| `[profiles.<name>]` | Human-readable description of `default`, `ai_agents`, or `cloud`. |
| `[packages.<profile>.<provider>.<category>]` | Operating-system package or desktop application. Providers are `os`, `cask`, or `flatpak` as appropriate for the host. |
| `[runtimes.<profile>.mise.<category>]` | Language runtime managed by Mise. |
| `[tools.<profile>.mise.<category>]` | Versioned CLI managed by Mise, including `npm:` and `ubi:` backends. |
| `[containers.default.<provider>.<category>]` | Optional container-runtime bundle, consumed only by `-Containers` / `--containers` after the recipe validates the manifest. |

`default` is always selected. Add `ai-agents` and/or `cloud` with `-Profile ai-agents,cloud` on Windows or `--profile ai-agents,cloud` on macOS and Linux. The recipes normalise the command-line spelling `ai-agents` to the TOML key `ai_agents`.

A non-empty version asks the recipe to install the entry. `"latest"` tracks the provider's current package. Optional runtimes are represented by commented-out `"latest"` entries in `[runtimes.default.mise.optional]`; uncomment an entry to opt in. Linux support in this repository means the implemented APT/Flatpak route, not every Linux distribution.

## Provider documentation

Provider IDs are local to their provider. Find an ID in its provider catalogue; do not substitute an executable name, an application display name, or an ID from another provider. Provider configuration, activation, updates, troubleshooting, and recovery remain provider responsibilities. DevRecipe deliberately does not provide provider-wide update, cleanup, or rollback commands.

Windows is the one activation exception in the shipped recipe: when selected entries include Mise runtimes or tools, DevRecipe runs `mise reshim`, adds `%LOCALAPPDATA%\mise\shims` to the signed-in user's `PATH` for `cmd.exe` and new processes, and adds `mise activate <shell> --shims` hooks for compatible shells available on the host: PowerShell, Nushell, Bash, Zsh, Fish, Elvish, and Xonsh. Mise has no `cmd.exe` activation shell, so the user `PATH` entry is the supported fallback. Existing terminals and VS Code processes keep their inherited `PATH`; open a new terminal after installation.

| Provider | Used by DevRecipe for | Official documentation |
| --- | --- | --- |
| Scoop | Windows packages | [Quick Start](https://github.com/ScoopInstaller/Scoop/wiki/Quick-Start) · [commands](https://github.com/ScoopInstaller/Scoop/wiki/Commands) |
| Homebrew | macOS formulae and casks | [installation](https://docs.brew.sh/Installation) · [command reference](https://docs.brew.sh/Manpage) · [troubleshooting](https://docs.brew.sh/Troubleshooting) |
| APT | Ubuntu/Debian packages | [APT User's Guide](https://www.debian.org/doc/manuals/apt-guide/) |
| Flatpak | Ubuntu/Debian user-scoped desktop applications | [Using Flatpak](https://docs.flatpak.org/en/latest/using-flatpak.html) |
| Mise | Runtimes and versioned CLIs on every supported host | [Getting Started](https://mise.jdx.dev/getting-started) · [Dev Tools](https://mise.jdx.dev/dev-tools/) |

## Proposed default coverage

These tables describe the repository's proposed defaults, not a cross-platform requirement. Users may customise each host manifest independently. A provider package ID is sent to its declared provider as written; it is not treated as a universal application or executable identity.

Platform-specific choices and omissions remain explicit in [platform-specific choices](#platform-specific-choices). Their presence in this reference does not cause recipes to validate or add matching entries on other hosts.

## Core tools

| Capability | Windows | macOS | Linux |
| --- | --- | --- | --- |
| Source control | Scoop `git` | Homebrew `git` | APT `git` |
| Terminal | Scoop `alacritty` | Cask `alacritty` | Flatpak `org.alacritty.Alacritty` |
| Structured shell | Scoop `nushell` | Homebrew `nushell` | Mise `"ubi:nushell/nushell"` |
| Runtime manager | Scoop `mise` | Homebrew `mise` | Installed from the Mise bootstrap script |
| Compiler and build tools | Scoop `gcc`, `make` | Homebrew `gcc`; external Xcode Command Line Tools supply `make` | APT `gcc`, `make` |
| POSIX utilities | Scoop `coreutils`, `sed`, `gawk` | Homebrew `coreutils` | Native distribution utilities; no duplicate declaration |
| DNS and network tools | Scoop `bind-tooling`, `nmap`, `netcat` | Homebrew `bind`, `nmap`, `netcat` | APT `bind9-dnsutils`, `nmap`, `netcat-openbsd` |
| Local development web server | Scoop `nginx` | Homebrew `nginx` | APT `nginx` |
| Search and navigation | Scoop `ripgrep`, `fd`, `bat`, `fzf` | Homebrew `ripgrep`, `fd`, `bat`, `fzf` | APT `ripgrep`, `fd-find`, `bat`, `fzf` |
| HTTP client | Scoop `curl` | Homebrew `curl` | APT `curl` |
| Archive tool | Scoop `7zip` | Homebrew `7zip` | APT `7zip` |
| GitHub tooling | Scoop `gh` | Homebrew `gh` | APT `gh` |

## Default database clients

The default profile installs both DBeaver and the following command-line clients. It does not start database servers or create local data stores.

| Client | Windows | macOS | Linux |
| --- | --- | --- | --- |
| SQLite | Scoop `sqlite` | Homebrew `sqlite` | APT `sqlite3` |
| PostgreSQL | Scoop `postgresql` | Homebrew `libpq` | APT `postgresql-client` |
| MySQL / MariaDB | Scoop `mysql` | Homebrew `mysql-client` | APT `default-mysql-client` |
| Redis | Scoop `redis` | Homebrew `redis` | APT `redis-tools` |

Homebrew can treat the client-only `libpq` and `mysql-client` formulae as keg-only. The macOS recipe does not modify the global shell `PATH`; configure any client path deliberately after considering existing tools.

## Runtimes managed by Mise

| Runtime | Windows | macOS | Linux |
| --- | --- | --- | --- |
| Node.js | `node = "latest"` | `node = "latest"` | `node = "latest"` |
| pnpm | `pnpm = "latest"` | `pnpm = "latest"` | `pnpm = "latest"` |
| Python | `python = "latest"` | `python = "latest"` | `python = "latest"` |
| Java | `java = "latest"` | `java = "latest"` | `java = "latest"` |
| Optional Go, Rust, Bun, Deno, Ruby, PHP | Commented-out `"latest"` entries; not installed | Commented-out `"latest"` entries; not installed | Commented-out `"latest"` entries; not installed |

## Desktop and development applications

| Capability | Windows | macOS | Linux |
| --- | --- | --- | --- |
| Code editor | Scoop `vscode` | Cask `visual-studio-code` | Flatpak `com.visualstudio.code` |
| Database client | Scoop `dbeaver` | Cask `dbeaver-community` | Flatpak `io.dbeaver.DBeaverCommunity` |
| Diagram editor | Scoop `yed` | Cask `yed` | Flatpak `com.yworks.yEd` |
| Knowledge bases | Scoop `logseq`, `obsidian` | Casks `logseq`, `obsidian` | Flatpaks `com.logseq.Logseq`, `md.obsidian.Obsidian` |
| Media player | Scoop `vlc` | Cask `vlc` | Flatpak `org.videolan.VLC` |
| API client | Scoop `bruno` | Cask `bruno` | Flatpak `com.usebruno.Bruno` |
| LDAP client | Scoop `apache-directory-studio` | Cask `apache-directory-studio` | Not currently declared; use Apache Directory Studio's upstream package if required |
| Developer browser | Scoop `firefox-developer` | Cask `firefox-developer-edition` | Flatpak `org.mozilla.firefox` (**standard Firefox**, not Developer Edition) |
| Text expander | Scoop `espanso` | Cask `espanso` | Not currently declared |
| Lightweight editor | Scoop `notepadplusplus` | Cask `zed` | Flatpak `dev.zed.Zed` |
| Terminal multiplexer GUI | Scoop `mobaxterm` | Cask `tabby` | Flatpak `org.tabbyml.Tabby` |
| Diff and merge tool | Scoop `meld` | Cask `meld` | Flatpak `org.gnome.meld` |
| Platform utilities | Scoop `powertoys` | Cask `raycast` | No direct package is currently declared |

## `ai-agents` profile

This optional profile assumes the default Node.js runtime. It keeps GUI and terminal AI tooling out of the daily baseline. The table records the current default proposals; it does not require a user-customised host to contain every row.

| Capability | Windows | macOS | Linux |
| --- | --- | --- | --- |
| GitHub Copilot CLI | Mise `"npm:@github/copilot"` | Same Mise entry | Same Mise entry |
| Claude Desktop | Scoop `claude` | Cask `claude` | Anthropic APT `claude-desktop` (beta) |
| Claude Code | Mise `"npm:@anthropic-ai/claude-code"` | Same Mise entry | Same Mise entry |
| Gemini CLI | Mise `"npm:@google/gemini-cli"` | Same Mise entry | Same Mise entry |
| Codex CLI | Mise `"npm:@openai/codex"` | Same Mise entry | Same Mise entry |

On Linux, selecting `ai-agents` causes the recipe to configure Anthropic's signed APT repository immediately before it installs `claude-desktop`. Claude Desktop remains distinct from Claude Code.

## `cloud` profile

Cloud tools are Mise-managed in the shipped manifests. Installing this profile does not authenticate to an account, create a Kubernetes cluster, or select a cloud subscription.

| Capability | Mise declaration |
| --- | --- |
| AWS CLI | `awscli = "latest"` |
| Azure CLI | `azure-cli = "latest"` |
| Google Cloud CLI | `gcloud = "latest"` |
| Kubernetes client | `kubectl = "latest"` |
| Helm | `helm = "latest"` |
| OpenTofu | `opentofu = "latest"` |

## Containers

Container packages remain separate because an engine can need host virtualisation support. Each platform declares an optional bundle; the normal base installation does not run it. The matching public recipe consumes the bundle only with `-Containers` / `--containers`.

| Component | Windows | macOS | Linux |
| --- | --- | --- | --- |
| Podman engine | `[containers.default.os.engine]` `podman`; existing Podman machine or WSL 2 Podman distribution preserved, then ready WSL 2, then ready Hyper-V | `[containers.default.os.engine]` `podman`; creates one machine only when none exists | `[containers.default.os.engine]` `podman`; native rootless engine |
| Rootless prerequisites | Windows virtualisation features are prepared only when needed | A Podman machine provides the Linux runtime | `[containers.default.os.rootless]` `uidmap`, `fuse-overlayfs` |
| Podman Desktop | `[containers.default.os.engine]` `podman-desktop` from Scoop Extras | Not bundled | Not bundled |
| Compose provider | `[containers.default.os.compatibility]` `docker-compose`; invoked through `podman compose` | Not bundled | Not bundled |
| Kubernetes CLI | `cloud` profile via Mise; client only, no local cluster enabled | `cloud` profile via Mise; client only | `cloud` profile via Mise; client only |
| Recommended workflow | Run `DevRecipe_windows.ps1 -Containers`; follow the [Windows provider policy](container-provider-policy.md) | Run `bash ./DevRecipe_unix.bash --containers` | Run `bash ./DevRecipe_unix.bash --containers` |

For exact setup and verification, see [Install DevRecipe](installation.md#install-a-container-runtime-deliberately). For the Windows tie-break and fallback rules, see [Windows Podman machine provider policy](container-provider-policy.md).

## Platform-specific choices

| Tool family | Windows | macOS | Linux |
| --- | --- | --- | --- |
| Windows-native editing | Notepad++ is retained because it is a native Win32 tool | Zed provides the corresponding lightweight editor role | Zed provides the corresponding lightweight editor role |
| Window/workflow utility | PowerToys | Raycast | No equivalent is declared; choose a desktop-environment-specific tool |
| Remote terminal | MobaXterm | Tabby | Tabby |
| Browser channel | Firefox Developer Edition | Firefox Developer Edition | Standard Firefox from Flathub in the current manifest |

To change a manifest, use the [user guide](user-guide.md). This reference names the current raw IDs and deliberate platform differences.
