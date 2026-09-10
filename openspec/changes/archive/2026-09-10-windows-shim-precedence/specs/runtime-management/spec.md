## MODIFIED Requirements

### Requirement: Windows Mise Shims Activation
The system SHALL activate Mise and Scoop shims on Windows with guaranteed precedence by updating the user PATH environment variable, adding shell startup integration hooks, and configuring command processor AutoRun execution.

#### Scenario: User PATH includes Mise shims directory
- **WHEN** Mise runtimes or tools are installed on Windows
- **THEN** `%LOCALAPPDATA%\mise\shims` and `%USERPROFILE%\scoop\shims` are prepended to the user PATH in priority order if not already present

#### Scenario: Shell startup profiles are configured idempotently
- **WHEN** environment activation runs on Windows
- **THEN** shell startup hooks for PowerShell and compatible shells are configured without duplicating existing hook blocks to enforce shim precedence

#### Scenario: Command processor AutoRun is configured idempotently
- **WHEN** environment activation runs on Windows
- **THEN** a user-level script `%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd` is created and registered under `HKCU:\Software\Microsoft\Command Processor\AutoRun` to prepend Mise and Scoop shims to PATH for all `cmd.exe` sessions
