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
| AI desktop client | Scoop `claude` (from Scoop Extras) |

The AI client list includes GitHub Copilot CLI, Claude Code, Gemini CLI, and Codex. The exact provider IDs are in the [package matrix](package-matrix.md).

## Safe agent workflow

An agent must show the plan and obtain developer approval before it runs a mutating command.

### 1. Run the read-only checks

Run from the repository root:

```powershell
# Validate the manifest
./DevRecipe_windows.ps1 -Profile ai-agents -Validate

# List declared items
./DevRecipe_windows.ps1 -Profile ai-agents -List

# Preview the plan
./DevRecipe_windows.ps1 -Profile ai-agents -DryRun
```

Validation reads the manifest. List mode reads the declarations. Dry run runs the read-only preflight and prints provider bootstrap, package, runtime, and privilege boundaries. It does not mutate the host.

### 2. Explain the expected changes

The agent must summarize the dry-run output before installation. The summary must identify:

- the selected profile
- each provider and raw ID
- any bucket configuration or provider bootstrap
- any UAC action
- the Windows Mise PATH and shell-hook changes
- the fact that status is not ownership evidence

The agent must stop if the developer rejects a provider, source, package, runtime, or privilege boundary.

### 3. Install after approval

After approval, run the installation command:

```powershell
./DevRecipe_windows.ps1 -Profile ai-agents
```

Use `-Review` when the developer must approve each individual host write. Review requires a real interactive terminal. An agent that runs without a TTY must not assume that review can work.

On Windows, the `claude` package comes from Scoop Extras, and `[buckets]` ensures the bucket is configured.

### 4. Verify provider state

Run status with the same profile:

```powershell
./DevRecipe_windows.ps1 -Profile ai-agents -Status
```

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