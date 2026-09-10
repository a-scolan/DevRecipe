## Context

See proposal.md - Why.
Scoop on Windows requires auxiliary buckets when installing packages from outside the default `main` bucket. Previously, `extras` and `versions` were referenced through hardcoded checks in PowerShell. Moving bucket declarations to a top-level `[buckets]` table in `DevRecipe_windows.toml` makes the system completely flexible.

## Goals / Non-Goals

**Goals:**
- Define `[buckets]` in `DevRecipe_windows.toml` to declare required Scoop buckets globally for all profiles.
- Support key-value pairs where key is bucket name, and value is either `""` (for official Scoop buckets) or a repository URL (for custom buckets).
- Dynamically parse and ensure declared buckets in `DevRecipe_windows.ps1`.
- Update manifest validators in Python and PowerShell.

**Non-Goals:**
- Automatic bucket deletion upon package removal (buckets remain shared host assets).

## Decisions

### Decision 1: Top-level `[buckets]` table
- **Rationale**: Buckets are a package repository mechanism that applies globally across all profiles on Windows. Keeping it top-level `[buckets]` simplifies syntax and avoids per-profile duplication.

### Decision 2: Remove hardcoded application checks
- **Rationale**: Eliminating `if ($PackageNames -contains "firefox-developer")` ensures DevRecipe remains 100% data-driven and agnostic to specific package names.
