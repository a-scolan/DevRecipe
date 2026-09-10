# DevRecipe

Ever had to install multiple versions of Node and Python to run your agent harness, tools, and hooks? DevRecipe uses native package managers (Scoop, Homebrew, APT) and Mise to make workstation environments reproducible and reviewable for your teams.

DevRecipe turns a reviewed TOML manifest into repeatable package and runtime operations on supported developer hosts. It routes each declared identifier to its native provider and displays planned changes before execution.

## Why use it

- Keep a readable workstation baseline in source control.
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

Then run the matching read-only commands from its root:

| Host | Validate | List | Dry run | Install |
| --- | --- | --- | --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Validate` | `./DevRecipe_windows.ps1 -List` | `./DevRecipe_windows.ps1 -DryRun` | `./DevRecipe_windows.ps1` |
| macOS | `bash ./DevRecipe_unix.bash --validate` | `bash ./DevRecipe_unix.bash --list` | `bash ./DevRecipe_unix.bash --dry-run` | `bash ./DevRecipe_unix.bash` |
| Ubuntu/Debian | `bash ./DevRecipe_unix.bash --validate` | `bash ./DevRecipe_unix.bash --list` | `bash ./DevRecipe_unix.bash --dry-run` | `bash ./DevRecipe_unix.bash` |

`default` is always selected. Add `ai-agents` or `cloud` with `-Profile` on Windows or `--profile` on macOS and Linux. Command-line profiles use hyphens. TOML profile keys use underscores, such as `ai_agents`.

Use [Start and customize DevRecipe](docs/quick-start.md) for a first change. Use [Install DevRecipe](docs/installation.md) when the manifest is ready.

## What it manages

| Host | Package route | Runtime and CLI route |
| --- | --- | --- |
| Windows | Scoop | Mise |
| macOS | Homebrew formulae and casks | Mise |
| Ubuntu/Debian | APT and user-scoped Flatpak | Mise |

Container setup is separate and opt-in. Use `-Containers` on Windows or `--containers` on macOS and Ubuntu/Debian. See the [container provider policy](docs/container-provider-policy.md) before changing Windows virtualization features.

## Important boundaries

- A manifest contains provider IDs. It does not contain executable-name guesses.
- Validation and list mode read the manifest only. Dry run does not mutate the host, but it runs the read-only preflight and can query providers.
- Preflight reports bounded conflict evidence. Use `-SkipPreflight` or `--skip-preflight` to bypass it.
- Use `-Force` or `--force` to pre-approve non-fatal conflicts.
- Status reports what the declared provider lists. It does not prove that DevRecipe installed or owns the item.
- Removal targets only confirmed exact IDs. It does not remove dependencies, configuration, credentials, containers, provider bootstraps, or operating-system features.
- DevRecipe does not configure applications, install secrets, create services, or manage provider-wide updates and rollback.
- Windows Mise activation needs a new terminal or VS Code process after installation.
- On Linux, selecting `ai-agents` adds Anthropic's signed APT source for `claude-desktop` and needs `sudo`.

Read the [status and removal reference](docs/status-and-removal.md) and [preflight and review reference](docs/preflight-and-review.md) for exact behavior.

## AI agent use case

[Prepare an execution environment for an AI agent](docs/ai-agent-use-case.md) shows how an agent can install the runtimes and AI command-line tools needed to process a developer request. The example also states what remains outside DevRecipe: plugins, skills, hooks, agent definitions, credentials, and application configuration belong to the target IDE or agent framework.

## Documentation map

| User need | Document |
| --- | --- |
| Learn the first safe change | [Start and customize DevRecipe](docs/quick-start.md) |
| Install a reviewed baseline | [Install DevRecipe](docs/installation.md) |
| Change, inspect, or remove an entry | [Manage a DevRecipe manifest](docs/user-guide.md) |
| Find exact IDs and platform differences | [Package matrix](docs/package-matrix.md) |
| Understand preflight and human review | [Preflight and review](docs/preflight-and-review.md) |
| Understand status and removal limits | [Status and removal](docs/status-and-removal.md) |
| Understand Windows Podman selection | [Container provider policy](docs/container-provider-policy.md) |
| Review privilege and team boundaries | [Enterprise governance](docs/enterprise-governance.md) |
| Test a change on a disposable host | [Manual validation](docs/manual-validation.md) |
| Run local test gates | [Acceptance checks](tests/acceptance/README.md) |
| Understand what the test suite proves | [Baseline acceptance test](docs/baseline-acceptance-test.md) |
| See future scope | [Roadmap](docs/roadmap.md) |

## Supported hosts

The base recipe supports Windows, macOS, and Ubuntu/Debian. Fedora, RHEL, Arch, and Pacman are not supported by the current route.

Use the [provider documentation](docs/package-matrix.md#provider-documentation) for package IDs, provider configuration, provider updates, and provider-specific recovery.
