## Why

On locked-down Windows enterprise machines, system environment variables (`HKLM`) cannot be modified without administrative privileges. Because Windows process initialization concatenates the system `PATH` before the user `PATH` (`HKCU`), stale system installations (such as legacy Python 2.7/3.7) take precedence over user-installed runtimes in Mise and packages in Scoop. This breaks tools invoked by IDEs (like VS Code), build scripts, and `cmd.exe` sub-processes. DevRecipe needs a robust, non-admin mechanism to enforce shim precedence across all execution contexts.

## What Changes

- Add a generic Windows user-space shim precedence helper script (`%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd`) that prepends Mise and Scoop shims to `PATH`.
- Configure `cmd.exe` AutoRun in `HKCU:\Software\Microsoft\Command Processor` to invoke this shim helper silently on every command processor instance.
- Update Windows shell configuration routines to ensure both Mise shims (`%LOCALAPPDATA%\mise\shims`) and Scoop shims (`%USERPROFILE%\scoop\shims`) precede system paths in interactive shells.
- Integrate the `cmd.exe` AutoRun setup into the human review approval system (`Confirm-DevRecipeReviewAction`) and dry-run preview.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `runtime-management`: Extend Windows environment activation to enforce Mise and Scoop shim precedence across interactive shells and `cmd.exe` sub-processes via user-level AutoRun hooks.

## Impact

- `DevRecipe_windows.ps1`: Shell activation logic and user environment configuration updated to manage Scoop shims and `cmd.exe` AutoRun.
- User registry: Writes user-level value `AutoRun` under `HKCU:\Software\Microsoft\Command Processor`.
- User filesystem: Creates `%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd`.
- No administrative rights required.
