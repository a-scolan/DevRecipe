## Why

The CLI interface currently includes redundant flags such as `-Preflight` / `--preflight` (which duplicates the default behavior during install/dry-run) while lacking a bypass flag like `-SkipPreflight` / `--skip-preflight`. Several parameter names are verbose or inconsistently structured across platforms (`-ContainerFeatureSetupOnly`, `-EnableDockerAlias`). Furthermore, the existing documentation is written in a dense, defensive legalistic style with long passive sentences and repetitive governance disclaimers. Refactoring the CLI flags and rewriting the entire documentation set into ASD-STE100 Simple English will make DevRecipe faster, easier to learn, and effortless to operate.

## What Changes

- Add `-SkipPreflight` / `--skip-preflight` flag to explicitly skip preflight conflict scans when quick unattended execution is desired.
- Keep `-Preflight` / `--preflight` as a recognized no-op alias for backwards compatibility with existing test suites.
- Introduce intuitive, shorter aliases: `--docker-alias` for `-EnableDockerAlias`, `--features-only` for `-ContainerFeatureSetupOnly`.
- Support subcommand verb syntax (`plan`, `validate`, `list`, `status`, `remove`) while maintaining full compatibility with legacy switch parameters (`-DryRun`, `-Validate`, etc.).
- Rewrite all documentation pages (`README.md` and all 12 files in `docs/`) in clear, concise Simple English (active voice, short sentences under 20 words, actionable steps, zero bureaucratic filler).

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `cli-interface`: Adds `-SkipPreflight` / `--skip-preflight`, shorter flag aliases (`--docker-alias`, `--features-only`), and verb-based execution modes.
- `preflight-conflict-detection`: Adds support for skipping preflight scanning entirely via `-SkipPreflight` / `--skip-preflight`.

## Impact

- CLI scripts: `DevRecipe_windows.ps1` and `DevRecipe_unix.bash`.
- Documentation files: `README.md` and all 12 documents in `docs/`.
- Specifications: delta specs for `cli-interface` and `preflight-conflict-detection`.
