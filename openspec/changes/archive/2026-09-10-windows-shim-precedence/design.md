## Context

See proposal.md - Why.
Under Windows, `CreateEnvironmentBlock` merges `HKLM` (Machine PATH) before `HKCU` (User PATH). When system PATH contains legacy installations (e.g., Python 2.7 in `C:\Python27`), user-level installations in Mise and Scoop are shadowed by default. Modifying HKLM is impossible without administrator rights.

## Goals / Non-Goals

**Goals:**
- Enforce precedence for `%LOCALAPPDATA%\mise\shims` and `%USERPROFILE%\scoop\shims` over system PATH across interactive shells and `cmd.exe` sub-processes.
- Remain 100% generic: do not pin or hardcode individual binary names (e.g. `python.exe`, `node.exe`). Dynamic versioning via Mise and Scoop must work seamlessly.
- Require zero administrative rights.
- Integrate with DevRecipe's review, preview, and preflight mechanisms.

**Non-Goals:**
- Tampering with machine-wide registry or attempting privilege elevation.
- Forcing process restarts (e.g. killing `explorer.exe`).
- Hardcoding IDE-specific configuration files.

## Decisions

### 1. `cmd.exe` AutoRun via HKCU
- **Decision**: Deploy `%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd` and register it in `HKCU:\Software\Microsoft\Command Processor\AutoRun`.
- **Implementation**: The script prepends Mise and Scoop shims to `%PATH%`, protected by an environment variable guard (`DEVRECIPE_SHIMS_PREPENDED`) to prevent redundant PATH growth in nested calls:
  ```cmd
  @if not defined DEVRECIPE_SHIMS_PREPENDED (set "DEVRECIPE_SHIMS_PREPENDED=1" & set "PATH=%LOCALAPPDATA%\mise\shims;%USERPROFILE%\scoop\shims;%PATH%")
  ```
- **Alternatives considered**:
  - *Hardcoding App Paths in HKCU*: Would require registering every executable individually (`python.exe`, `node.exe`), breaking per-project runtime switching.
  - *Restarting Explorer on login*: Invasive, potential security software (EDR) alerts.

### 2. Dual Shim Management in User PATH & Memory
- **Decision**: Update `Ensure-DevRecipeMiseShimsUserPath` to manage both Mise shims and Scoop shims in `HKCU:\Environment\Path` and `$env:Path`.
- **Order**: `%LOCALAPPDATA%\mise\shims` first, then `%USERPROFILE%\scoop\shims`, followed by existing entries.

### 3. Shell Profile Hooks Update
- **Decision**: Update `Enable-MiseShellShimsActivation` so that configured shell profiles (PowerShell, Bash, Zsh, Nu, etc.) ensure both Mise and Scoop shims take precedence in memory.

## Risks / Trade-offs

- **[Risk]** Programs invoking `cmd.exe /d` ignore the `AutoRun` registry entry.
  → **Mitigation**: Very few automated tools or IDE runners invoke `cmd /d`; standard `cmd.exe /c` used by Node, Python scripts, and build tools respect `AutoRun`. Shell profiles protect interactive usage.
- **[Risk]** Recursive sub-shells accumulating duplicate paths.
  → **Mitigation**: Guarded by `DEVRECIPE_SHIMS_PREPENDED` check in `shims_prepend.cmd`.
