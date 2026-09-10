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
The system SHALL require that only one primary execution mode is selected among validate, list, status, dry-run, uninstall, and install, supporting both direct action verbs and legacy mode switches.

#### Scenario: Multiple mode switches rejected
- **WHEN** a user specifies conflicting mode options simultaneously
- **THEN** execution terminates with exit code 2 and a usage message indicating only one mode may be selected

#### Scenario: Subcommand verbs and legacy flags supported identically
- **WHEN** a user calls `validate` or `-Validate` / `--validate`
- **THEN** manifest validation executes in non-mutating mode

### Requirement: Force Execution Flag
The system SHALL provide an explicit force flag (`-Force` on Windows, `--force` / `-f` on Unix) to pre-approve preflight conflict resolution and avoid interactive prompts when accepted by the operator.

#### Scenario: Force flag pre-approves detected preflight conflicts
- **WHEN** DevRecipe is executed with the force flag and non-fatal preflight conflicts are encountered
- **THEN** all detected entries are marked with decision force without presenting interactive menus or halting non-interactive runs

### Requirement: Cross-Platform Flag Parity
The system SHALL support consistent short and long flag aliases across Windows PowerShell and Unix Bash for common modifiers (`-Yes` / `--yes` / `-y`, `-Review` / `--review`, `-Containers` / `--containers`, `-Force` / `--force` / `-f`).

#### Scenario: Short flag aliases recognized on all platforms
- **WHEN** `-y` or `--yes` is passed to the removal command
- **THEN** removal execution proceeds without requiring platform-specific flag spellings

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
