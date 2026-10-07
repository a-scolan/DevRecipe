## Why

DevRecipe installs packages in user space without administrator privileges, relying on Scoop and Mise shims in the user `PATH`. However, two significant usability and architectural considerations need to be addressed:

1. **System PATH precedence documentation**: Under Windows, the operating system constructs process environments by merging Machine (`HKLM`) `PATH` before User (`HKCU`) `PATH`. For GUI applications (such as VS Code or desktop IDEs launched from the Start Menu or Explorer), system-installed binaries inevitably shadow user-space shims. This must be formally documented as a known current limitation of user-space bootstrapping.
2. **Optional global runtime activation**: DevRecipe currently executes `mise install <spec>` and `mise reshim`, but intentionally does not invoke `mise use -g`. On a clean developer machine with no prior `.mise.toml` or global configuration, installed runtimes (like `node` or `python`) are placed in the Mise store but are not immediately active or resolvable in new shells. Providing an optional global activation mechanism (via a CLI parameter or manifest directive) allows fresh workstations to have immediately usable runtimes, while strictly guaranteeing that any existing runtime installations on the host are never superseded or disrupted.

## What Changes

- **Document PATH Precedence Limitation**: Update `docs/installation.md` and `docs/package-matrix.md` to document that Windows merges `System PATH` ahead of `User PATH` for GUI applications, desktop launchers, and processes not invoking shell startup hooks or `cmd.exe` AutoRun.
- **Automatic Conflict-Aware Runtime Activation**: During standard Windows installation, DevRecipe inspects each selected default Mise runtime (`[runtimes.default.mise.*]`). If and only if no prior installation exists on the host (verified via preflight OS metadata evidence, existing PATH commands outside Mise shims, and pre-existing Mise active versions), DevRecipe automatically executes `mise use -g <name>@<version>`.
- **Preservation of Existing Runtimes**: If any pre-existing installation or active version is detected for a runtime, DevRecipe skips global activation for that runtime and logs an informative message explaining that the existing installation was preserved.
- **Interactive Review Integration**: When `-Review` is enabled, `mise use -g` operations appear as distinct review checkpoints with clear target, privilege, and effect details.

## Capabilities

### Modified Capabilities

- `runtime-management`: Specify automatic global runtime activation via `mise use -g` for default runtimes, conditioned on the complete absence of existing host installations for each runtime.

## Impact

- Modified files:
  - `DevRecipe_windows.ps1`: CLI parameters, conflict-safe global activation routine, review integration.
  - `DevRecipe_windows.toml` (optional setting or documentation).
  - `docs/installation.md`, `docs/package-matrix.md`, `docs/user-guide.md`: Document System PATH precedence limitation and `-ActivateGlobal` usage.
  - `tests/acceptance/test_baseline.py`, `tests/acceptance/manifest_contract.py`: Update contract and CLI tests.
