## Context

See proposal.md - Why.
The preflight mechanism in `DevRecipe_windows.ps1` and `DevRecipe_unix.bash` informs users about potential installation collisions with already-installed applications. The current banner text contains abstract jargon ("similarity is evidence ordering only, never identity or provenance").

## Goals / Non-Goals

**Goals:**
- Provide a clear, welcoming preflight explanation: "Scanning requested tools and checking your system for existing traces to prevent installation conflicts."
- Prepend each detected entry's evidence output with "Traces found for <application>:".
- Keep evidence line patterns intact (`evidence | query=...`) to avoid breaking existing contract checks.

**Non-Goals:**
- Altering the Levenshtein or prefix match algorithm.

## Decisions

### Decision 1: Human-Friendly Preflight Banner
- **Rationale**: Before launching the filesystem cache and registry queries, explain what is happening in one plain-English sentence.

### Decision 2: Clear "Traces found" Heading
- **Rationale**: Replaces or accompanies `--- PREFLIGHT CHECK: <name> ---` with `Traces found for <name>:` so users immediately know what the listed files/registries represent.
