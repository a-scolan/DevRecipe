# AI agent use case: prepare a developer execution environment

> Documentation type: how-to guide. Use this example when an AI agent needs a runtime before it can process a developer request.

## Situation

A developer asks an AI agent to inspect a repository, run tests, and use a command-line coding assistant. The agent needs a predictable execution environment for Node.js tools, Python tools, and the selected AI clients.

DevRecipe can install these runtimes and tools from the reviewed host manifest. It does not install or configure a plugin system. Plugins, skills, hooks, agent definitions, credentials, and application configuration belong to the IDE or agent framework that uses the environment.

## What the profile provides

The shipped `ai-agents` profile adds the following entries to the always-selected `default` profile:

| Need | Manifest entries |
| --- | --- |
| Node.js and pnpm | `runtimes.default.mise.web` |
| Python and Java | `runtimes.default.mise.backend` |
| AI command-line tools | `tools.ai_agents.mise.coding_agents` |
| AI desktop client | Platform-specific `claude` or `claude-desktop` package |

The AI client list includes GitHub Copilot CLI, Claude Code, Gemini CLI, and Codex. The exact provider IDs are in the [package matrix](package-matrix.md).

## Safe agent workflow

An agent must show the plan and obtain developer approval before it runs a mutating command.

### 1. Select the host command

Run from the repository root:

| Host | Validation | List | Dry run |
| --- | --- | --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Profile ai-agents -Validate` | `./DevRecipe_windows.ps1 -Profile ai-agents -List` | `./DevRecipe_windows.ps1 -Profile ai-agents -DryRun` |
| macOS or Ubuntu/Debian | `bash ./DevRecipe_unix.bash --profile ai-agents --validate` | `bash ./DevRecipe_unix.bash --profile ai-agents --list` | `bash ./DevRecipe_unix.bash --profile ai-agents --dry-run` |

Validation reads the manifest. List mode reads the declarations. Dry run runs the read-only preflight and prints provider bootstrap, package, runtime, and privilege boundaries. It does not mutate the host.

### 2. Explain the expected changes

The agent must summarize the dry-run output before installation. The summary must identify:

- the selected host and profiles
- each provider and raw ID
- any provider bootstrap
- any `sudo` or UAC action
- the Windows Mise PATH and shell-hook changes
- the fact that status is not ownership evidence

The agent must stop if the developer rejects a provider, source, package, runtime, or privilege boundary.

### 3. Install after approval

After approval, run the matching installation command:

| Host | Installation |
| --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Profile ai-agents` |
| macOS or Ubuntu/Debian | `bash ./DevRecipe_unix.bash --profile ai-agents` |

Use `-Review` or `--review` when the developer must approve each individual host write. Review requires a real interactive terminal. An agent that runs without a TTY must not assume that review can work.

On Linux, this profile adds Anthropic's signed APT source before it installs the Claude Desktop beta and requires `sudo`. On Windows, the `claude` package comes from Scoop Extras. The normal profile path does not add the bucket, so an approved Extras bucket must already exist.

### 4. Verify provider state

Run status with the same profile:

| Host | Status |
| --- | --- |
| Windows | `./DevRecipe_windows.ps1 -Profile ai-agents -Status` |
| macOS or Ubuntu/Debian | `bash ./DevRecipe_unix.bash --profile ai-agents --status` |

`installed` means that the provider lists the exact ID or Mise specification. It does not prove that DevRecipe installed the item. The agent must report an `unavailable` provider inventory as inconclusive.

Open a new terminal or VS Code process on Windows before the agent runs a command provided by Mise. Existing processes keep their old environment.

## Continue outside DevRecipe

After the runtime is ready, the target IDE or agent framework can install its own plugins, load skills, register hooks, and select agent definitions. That step must use the framework's documented mechanism and the developer's approved sources.

DevRecipe does not create those files, inject credentials, authenticate to AI services, or configure a repository. The agent must keep those actions separate and describe them before it performs them.

## Failure handling

| Result | Agent action |
| --- | --- |
| Exit `0` | Report completion, then run status. |
| Exit `2` | Report the command or manifest error. Do not retry silently. |
| Exit `3` | Report the unresolved conflict, rejected review, or missing interactive terminal. Do not mutate the host. |
| Other non-zero result | Report the provider or operating-system error from the output and ask how to proceed. |

The agent must not silently retry installation, run removal without explicit approval, treat status as ownership, or select containers unless the developer requests a container runtime.