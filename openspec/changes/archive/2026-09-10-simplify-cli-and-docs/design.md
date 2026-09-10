## Context

See proposal.md - Why.
DevRecipe operates through `DevRecipe_windows.ps1` and `DevRecipe_unix.bash`. Preflight scanning runs automatically during install and dry-run, making the explicit `-Preflight` flag redundant as an enabling switch. What users actually need is the ability to bypass preflight scans via `-SkipPreflight` / `--skip-preflight` for faster operations or in trusted environments. In addition, parameter names like `-EnableDockerAlias` and `-ContainerFeatureSetupOnly` are excessively verbose.

Finally, documentation files across `docs/` are dense and burdened with repeated legalese. Applying ASD-STE100 Simple English principles transforms them into lean, direct, task-oriented guides.

## Goals / Non-Goals

**Goals:**
- Add `-SkipPreflight` / `--skip-preflight` to deactivate preflight scanning.
- Keep `-Preflight` / `--preflight` as a recognized no-op alias to maintain 100% test compatibility.
- Add concise aliases: `--docker-alias` for `-EnableDockerAlias`, `--features-only` for `-ContainerFeatureSetupOnly`.
- Rewrite documentation in Simple English: active voice, sentences under 20 words, no jargon, clear procedural structure.

**Non-Goals:**
- Changing underlying provider installation mechanics.
- Bypassing `--review` approval checkpoints (human review remains interactive).

## Decisions

### Decision 1: Add `-SkipPreflight` and treat `-Preflight` as legacy no-op
- **Rationale**: Since preflight is active by default, `-Preflight` does nothing new. Keeping it as a valid switch avoids breaking tests, while adding `-SkipPreflight` provides the missing control.

### Decision 2: Add shorter aliases for verbose container flags
- **Rationale**: `-DockerAlias` / `--docker-alias` is clearer and matches developer expectations better than `-EnableDockerAlias`.

### Decision 3: Complete Documentation Rewrite in Simple English
- **Rationale**: Replaces bureaucratic disclaimers with concise, procedural instructions that developers can read and follow in seconds.

## Risks / Trade-offs

- [Risk] Skipping preflight may install over existing third-party packages without warning.
  → Mitigation: `-SkipPreflight` is an explicit opt-in flag; preflight remains the default.
