## Why

The current CLI interface mixes primary execution modes with secondary behavior modifiers, lacks non-interactive bypass for preflight checks (`--force` / `-Force`), uses verbose non-standard parameter names (`-ContainerFeatureSetupOnly`), and suffers from flag naming differences across platforms (`-Yes` vs `--yes` / `-y`). Refactoring the CLI interface provides clear subcommand-style semantics or cleanly partitioned parameters with consistent cross-platform naming and backward-compatible aliases.

## What Changes

- Clarify primary execution verbs (`validate`, `list`, `dry-run`, `status`, `install`, `uninstall`) while preserving compatibility with legacy switches (`-Validate`, `--validate`, etc.).
- Introduce explicit `--force` / `-Force` flag to bypass interactive conflict prompts during non-interactive or automated executions when preflight warnings are accepted.
- Harmonize boolean switches across Windows and Unix (`--yes` / `-y` / `-Yes`, `--review` / `-Review`, `--containers` / `-Containers`).
- Deprecate or alias verbose ad-hoc flags such as `-ContainerFeatureSetupOnly` into cleaner options (`--features-only` / `-FeaturesOnly`).
- Allow flexible profile syntax accepting both `kebab-case` and `snake_case` in command arguments and TOML references seamlessly.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `cli-interface`: Clarifies command syntax, introduces explicit force bypass for preflight checks, standardizes cross-platform flag aliases, and formalizes subcommand-like operational verbs.
- `preflight-conflict-detection`: Adds support for explicit non-interactive bypass via force flag.

## Impact

- `DevRecipe_windows.ps1` and `DevRecipe_unix.bash` parameter definitions and dispatch logic.
- Documentation in `README.md`, `docs/quick-start.md`, `docs/user-guide.md`, `docs/preflight-and-review.md`.
- Acceptance test fixtures in `tests/acceptance/` to verify both new and legacy parameter syntax.
