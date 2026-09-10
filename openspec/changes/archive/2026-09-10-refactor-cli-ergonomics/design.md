## Context

See proposal.md - Why.
DevRecipe operates through two platform entrypoints: `DevRecipe_windows.ps1` and `DevRecipe_unix.bash`. The current argument parsing relies on individual switch flags (`-Validate`, `-List`, `-Status`, `-DryRun`, `-Uninstall`) alongside modifiers (`-Preflight`, `-Review`, `-Yes`, `-Containers`). Adding non-interactive pipeline automation requires predictable forcing mechanisms and cleaner command composition.

## Goals / Non-Goals

**Goals:**
- Provide backward-compatible CLI ergonomics so existing documentation and commands continue to work.
- Add an explicit `-Force` / `--force` / `-f` parameter to auto-approve detected preflight conflicts without requiring an interactive TTY.
- Standardize shorthand flags (`-y` for `-Yes` / `--yes`, `-f` for `--force`).
- Normalize profile parsing so users can type either `ai-agents` or `ai_agents` seamlessly.

**Non-Goals:**
- Breaking existing parameter contracts or scripts that rely on `-Validate`, `-DryRun`, or `-Uninstall`.
- Removing the interactive TTY protection for `-Review` (review mode still demands explicit operator confirmation per action).

## Decisions

### Decision 1: Add `-Force` / `--force` / `-f` as a Preflight Decision Pre-emptor
- **Rationale**: Currently, when non-fatal conflicts are detected, execution aborts with exit code 3 if no interactive TTY is available. A force flag enables automated testing, CI pipelines, and advanced user automation by pre-approving all non-fatal preflight matches.
- **Alternatives considered**: Passing environment variables like `DEVRECIPE_FORCE=1`. Rejected because explicit CLI flags are more inspectable, discoverable via `--help`, and standard.

### Decision 2: Maintain Dual Mode Parsing (Subcommands + Legacy Switches)
- **Rationale**: In PowerShell, define a positional parameter `$Command` or alias existing switches so that both `.\DevRecipe_windows.ps1 validate` and `.\DevRecipe_windows.ps1 -Validate` work. Same for Unix bash.
- **Alternatives considered**: Full breaking rewrite to strict subcommands only. Rejected because it would invalidate existing documentation and tests before deprecation.

### Decision 3: Profile Name Tolerance
- **Rationale**: Replace hyphens with underscores internally across all profile resolvers, allowing `-Profile ai_agents` as well as `-Profile ai-agents`.

## Risks / Trade-offs

- [Risk] `-Force` might accidentally overwrite unintended third-party packages.
  → Mitigation: `-Force` only overrides preflight non-fatal conflict detection; it does not bypass provider errors or `--review` checkpoints.
- [Risk] Argument parsing collisions between positional arguments and switches.
  → Mitigation: Use PowerShell parameter sets and explicit check ordering in Bash.
