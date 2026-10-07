## Context

See `proposal.md` - Why.
DevRecipe provisions Windows developer environments without administrative elevation, installing binaries into `%USERPROFILE%\scoop` and `%LOCALAPPDATA%\mise`.
Environment precedence is enforced for `cmd.exe` via `%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd` in `HKCU:\Software\Microsoft\Command Processor\AutoRun`, and in interactive shell profiles via startup hooks.
However:
1. Windows inherently merges `System PATH` (`HKLM`) before `User PATH` (`HKCU`) when creating process environments for GUI applications and desktop launchers.
2. DevRecipe currently executes `mise install` without `mise use -g`, leaving runtimes inactive on clean workstations unless the user manually creates a `.mise.toml` or runs `mise use -g`.

## Goals / Non-Goals

**Goals:**
- Document the `System PATH` precedence behavior and its effects on GUI applications (such as VS Code) in `docs/installation.md` and `docs/package-matrix.md`.
- Implement automatic conflict-safe global activation for default Mise runtimes during standard Windows installation.
- Implement safe conflict detection before running `mise use -g`:
  - Verify that no external installation of the runtime exists on the host (checking preflight OS evidence, App Paths, Registry, and PATH outside Mise shims).
  - Verify that Mise does not already have an existing active version configured for that runtime.
- For each approved runtime without existing conflicts, execute `mise use -g <name>@<version>` and integrate this action into interactive `-Review` checkpoints.
- Ensure that if an existing installation or active configuration is detected, global activation is skipped to avoid superseding existing runtimes.

**Non-Goals:**
- Requesting administrative privileges or altering machine-wide `HKLM` environment variables.
- Overwriting existing project `.mise.toml` files or existing user global configurations.
- Activating CLI tools (`[tools.*]`) that operate via standalone shims without language version switches.

## Decisions

### 1. Conflict-Aware Pre-Check for Global Activation
- **Decision**: Before executing `mise use -g <name>@<version>`, DevRecipe runs a multi-source conflict check:
  1. *Host Evidence*: Check if preflight collected OS metadata evidence (registry uninstall, App Paths, filesystem cache, or services) for `<name>`.
  2. *Command Resolution*: Test if `Get-Command <name>` resolves to an executable whose path is outside `$env:LOCALAPPDATA\mise\shims` and `$env:USERPROFILE\scoop\shims`.
  3. *Mise Active Configuration*: Check if `mise current <name>` already returns an active version configured prior to the run.
- **Outcome**: If any of these checks find an existing installation or active configuration, `mise use -g` is skipped for that runtime, and DevRecipe outputs an informational log: `Global activation skipped for <name>: existing installation or configuration detected.`
- **Alternatives considered**:
  - *Unconditional `mise use -g`*: Rejected. It would overwrite existing operator configurations and supersede system tools against user instructions.
  - *Requiring a dedicated CLI switch*: Rejected per operator requirements; automatic activation for newly installed default runtimes with zero conflicts provides seamless first-run developer experience.

### 2. Automatic Global Activation of Default Runtimes
- **Decision**: Automatically attempt global activation for installed runtimes declared under `[runtimes.default.mise.*]` (e.g. `node`, `python`, `java`). Tools under `[tools.*]` and optional profiles remain untouched.

### 3. Execution Placement in Installation Lifecycle
- **Decision**: Perform global activation immediately after `mise install` completes and before `mise reshim` and shims environment activation.
- **Rationale**: `mise use -g` updates the global configuration (`config.toml`), so the subsequent `mise reshim` immediately generates and aligns shims for the newly activated runtimes.

### 4. Interactive Review Integration
- **Decision**: Include each planned `mise use -g` operation in the interactive review pipeline when `-Review` is enabled.
- **Specification**: Command: `mise use -g <name>@<version>`, Privilege: `user`, Source: `Mise global configuration`, Effect: `activate <name> globally as default user runtime`.

## Risks / Trade-offs

- **[Risk]** A runtime executable (e.g., `python.exe` from Windows Store execution alias) triggers a false positive and prevents global activation.
  → **Mitigation**: The preflight conflict check specifically identifies actual installations. If an existing alias exists, preserving it by default is safer, and the user is clearly informed by the log message.
- **[Risk]** GUI applications (VS Code) continue to use System PATH binaries even after global activation.
  → **Mitigation**: Documented explicitly in `docs/installation.md` with instructions to launch VS Code from a configured shell (`code .`) or configure terminal path settings.
