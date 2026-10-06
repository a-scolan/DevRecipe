# DevRecipe

Ever had to install multiple versions of Node and Python to run your agent harness, tools, and hooks? DevRecipe uses Scoop and Mise to make Windows workstation environments reproducible and reviewable for your teams.

DevRecipe turns a reviewed TOML manifest into repeatable package and runtime operations on Windows developer workstations. It routes each declared identifier to Scoop or Mise and displays planned changes before execution.

## DevRecipe vs Scoop and Mise directly

While **Scoop** manages Windows developer tools and **Mise** manages language runtimes, using them directly requires manual setup, separate configuration files, and ad-hoc commands. DevRecipe unifies them into a coherent, safe, and automated workstation management system:

- **Single declarative contract**: All applications, developer utilities, and language runtimes are declared in one version-controlled TOML manifest ([DevRecipe_windows.toml](DevRecipe_windows.toml)) partitioned into customizable profiles (`default`, `ai-agents`, `cloud`).
- **Conflict preflight audit**: Neither Scoop nor Mise checks if a tool is already installed elsewhere on Windows. DevRecipe scans registry records, App Paths, AppX packages, Windows services, and tasks before mutating the host, alerting you to potential collisions and offering interactive resolution.
- **Zero-touch bootstrapping**: On a fresh workstation, DevRecipe automatically bootstraps Scoop, verifies Git prerequisites, configures required buckets, and provisions Mise in the proper dependency order.
- **Enforced shim precedence without admin rights**: In locked-down enterprise environments where system `PATH` (`HKLM`) overrides user tools, DevRecipe configures `cmd.exe` AutoRun and shell profiles to guarantee user-level Scoop and Mise shims take precedence without requiring administrator elevation.
- **Safety, review, and auditability**: Preview changes with simulation mode (`-DryRun`), approve mutations step-by-step with interactive review (`-Review`), perform exact-ID uninstallations (`-Uninstall`), track progress with real-time indicators, and review complete execution logs archived under `logs/`.

## Why use it

- Keep a readable Windows workstation baseline in source control.
- Rebuild a host with the same declared tools and runtimes.
- Separate daily tools from optional AI and cloud tools.
- Review provider bootstrap, privilege, and conflict decisions before writes.
- Use provider-native status and narrow exact-ID removal.

DevRecipe is useful for an individual developer, a team baseline, or a platform team that needs a reviewable starting point. It does not replace the package provider or an application configuration system.

## Start here

Clone the repository first:

```text
git clone https://github.com/a-scolan/DevRecipe DevRecipe
cd DevRecipe
```

Then run the matching read-only commands from PowerShell:

| Goal | Command |
| --- | --- |
| Validate manifest | `./DevRecipe_windows.ps1 -Validate` |
| List declared packages | `./DevRecipe_windows.ps1 -List` |
| Dry run | `./DevRecipe_windows.ps1 -DryRun` |
| Install | `./DevRecipe_windows.ps1` |

`default` is always selected. Add `ai-agents` or `cloud` with `-Profile`. Command-line profiles use hyphens (e.g. `-Profile ai-agents,cloud`). TOML profile keys use underscores, such as `ai_agents`.

Use [Start and customize DevRecipe](docs/quick-start.md) for a first change. Use [Install DevRecipe](docs/installation.md) when the manifest is ready.

## What it manages

| Provider | Purpose |
| --- | --- |
| Scoop | Windows CLI tools, developer utilities, and desktop applications |
| Mise | Language runtimes and CLI tools (e.g. Node, Python) |

Container setup is separate and opt-in via `-Containers`. See the [container provider policy](docs/container-provider-policy.md) before changing Windows virtualization features.

## Important boundaries

- A manifest contains provider IDs. It does not contain executable-name guesses.
- Validation and list mode read the manifest only. Dry run does not mutate the host, but it runs the read-only preflight and can query providers.
- Preflight reports bounded conflict evidence. Use `-SkipPreflight` to bypass it.
- Use `-Force` to pre-approve non-fatal conflicts.
- Status reports what the declared provider lists. It does not prove that DevRecipe installed or owns the item.
- Removal targets only confirmed exact IDs. It does not remove dependencies, configuration, credentials, containers, provider bootstraps, or operating-system features.
- Standard Windows installation updates Scoop itself and its catalogs, maintains installed or required Scoop-managed Mise, and updates selected installed Scoop `latest` entries.
- Windows Mise requests can use `latest`, partial versions, `prefix:` selectors, or supported aliases such as `lts`. Concrete version pins remain unchanged.
- DevRecipe does not configure applications, install secrets, create services, update unrelated applications, or provide rollback.
- Installing a newer Mise runtime does not change global or project version selection. Windows Node work rebuilds its shims and tests parent-child communication.
- Windows Mise activation needs a new terminal or VS Code process after installation.

Read the [status and removal reference](docs/status-and-removal.md) and [preflight and review reference](docs/preflight-and-review.md) for exact behavior.

## AI agent use case

[Prepare an execution environment for an AI agent](docs/ai-agent-use-case.md) shows how an agent can install the runtimes and AI command-line tools needed to process a developer request on Windows. The example also states what remains outside DevRecipe: plugins, skills, hooks, agent definitions, credentials, and application configuration belong to the target IDE or agent framework.

## Documentation map

| User need | Document |
| --- | --- |
| Learn the first safe change | [Start and customize DevRecipe](docs/quick-start.md) |
| Install a reviewed baseline | [Install DevRecipe](docs/installation.md) |
| Change, inspect, or remove an entry | [Manage a DevRecipe manifest](docs/user-guide.md) |
| Find exact IDs and details | [Package matrix](docs/package-matrix.md) |
| Understand preflight and human review | [Preflight and review](docs/preflight-and-review.md) |
| Understand status and removal limits | [Status and removal](docs/status-and-removal.md) |
| Understand Windows Podman selection | [Container provider policy](docs/container-provider-policy.md) |
| Review privilege and team boundaries | [Enterprise governance](docs/enterprise-governance.md) |
| Test a change on a disposable host | [Manual validation](docs/manual-validation.md) |
| Run local test gates | [Acceptance checks](tests/acceptance/README.md) |
| Understand what the test suite proves | [Baseline acceptance test](docs/baseline-acceptance-test.md) |
| See future scope | [Roadmap](docs/roadmap.md) |

## Supported host

DevRecipe currently targets Windows workstations using Windows PowerShell 5.1 or later.

Use the [provider documentation](docs/package-matrix.md#provider-documentation) for package IDs, provider configuration, provider updates, and provider-specific recovery.
