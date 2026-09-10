# CLI Interface

## Purpose
Exposes standardized command-line entry points for executing DevRecipe operations across supported operating systems.

## Requirements

### Requirement: Platform Native Entrypoints
The system SHALL provide `DevRecipe_windows.ps1` for Windows PowerShell and `DevRecipe_unix.bash` for macOS and Linux.

#### Scenario: Windows script executes on Win32NT
- **WHEN** executed on a Windows host
- **THEN** `DevRecipe_windows.ps1` validates prerequisites and operates with Windows native tools

#### Scenario: Unix script executes on macOS and Linux
- **WHEN** executed on macOS or Linux
- **THEN** `DevRecipe_unix.bash` detects the operating system, verifies host compatibility, and runs with bash 4+

### Requirement: Mutual Execution Mode Exclusivity
The system SHALL require that only one primary execution mode is selected among validate, list, status, dry-run, uninstall, and install.

#### Scenario: Multiple mode switches rejected
- **WHEN** a user specifies conflicting mode options simultaneously
- **THEN** execution terminates with exit code 2 and a usage message indicating only one mode may be selected

### Requirement: Predictable Standard Exit Codes
The system SHALL return standard process exit codes across all entrypoints and platforms.

#### Scenario: Success returns 0
- **WHEN** the requested operation completes successfully
- **THEN** the script terminates with exit code 0

#### Scenario: Usage or manifest error returns 2
- **WHEN** command-line arguments are invalid or manifest validation fails
- **THEN** the script terminates with exit code 2

#### Scenario: Unresolved conflict or rejected review returns 3
- **WHEN** preflight conflicts remain unresolved or review approval is declined
- **THEN** the script terminates with exit code 3
