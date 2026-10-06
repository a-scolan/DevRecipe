# CLI Interface

## Purpose
Exposes standardized command-line entry points for executing DevRecipe operations across supported operating systems.

## Requirements

### Requirement: Mutual Execution Mode Exclusivity
The system SHALL require that only one primary execution mode is selected among validate, list, status, dry-run, uninstall, and install, supporting both direct action verbs and legacy mode switches.

#### Scenario: Multiple mode switches rejected
- **WHEN** a user specifies conflicting mode options simultaneously
- **THEN** execution terminates with exit code 2 and a usage message indicating only one mode may be selected

#### Scenario: Subcommand verbs and legacy flags supported identically
- **WHEN** a user calls `validate` or `-Validate` / `--validate`
- **THEN** manifest validation executes in non-mutating mode

### Requirement: Force Execution Flag
The system SHALL provide an explicit force flag (`-Force`) in Windows PowerShell to pre-approve preflight conflict resolution and avoid interactive prompts when accepted by the operator.

#### Scenario: Force flag pre-approves detected preflight conflicts
- **WHEN** DevRecipe is executed with the force flag and non-fatal preflight conflicts are encountered
- **THEN** all detected entries are marked with decision force without presenting interactive menus or halting non-interactive runs

### Requirement: Preflight Bypass Option
The system SHALL allow operators to explicitly disable preflight conflict checking via a bypass flag (`-SkipPreflight`).

#### Scenario: Preflight scanning skipped when requested
- **WHEN** execution includes `-SkipPreflight`
- **THEN** DevRecipe skips conflict detection scans entirely and proceeds directly to planning or installation

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

### Requirement: Windows Native Entrypoint
The system SHALL provide `DevRecipe_windows.ps1` for Windows PowerShell as the dedicated entrypoint for workstation bootstrapping.

#### Scenario: Windows script executes on Win32NT
- **WHEN** executed on a Windows host
- **THEN** `DevRecipe_windows.ps1` validates prerequisites and operates with Windows native tools

### Requirement: Global Multi-Package Installation Progress Tracking
During standard installation runs, the system SHALL display an overall progress indicator that tracks total package and runtime progression across both Scoop and Mise operations.
The progress indicator SHALL report both the current step count `[X/N]` and an accurate overall percentage calculation.
On systems supporting interactive consoles, it SHALL present a visual progress bar that updates as each item completes.

#### Scenario: Multi-package installation displays progress percentage
- **WHEN** multiple Scoop packages and Mise runtimes are approved for installation or update
- **THEN** the system updates a global progress indicator with step counts and percentage as each component is processed
- **AND** completes the progress display once all approved items have been processed

### Requirement: Workspace Execution Log Persistence
The system SHALL automatically capture all raw, unfiltered stdout and stderr output from provider commands into a timestamped execution log file within the workspace `logs/` directory.
If the workspace `logs/` directory does not exist, the system SHALL create it before executing provider operations.

#### Scenario: Execution logs are saved to workspace logs directory
- **WHEN** a standard Windows installation is executed
- **THEN** a log file named `logs/devrecipe-windows-<timestamp>.log` is created in the script workspace
- **AND** all raw provider command outputs, errors, and traces are written to this log file

### Requirement: Post-Execution Component Summary
At the conclusion of the installation run, the system SHALL output a structured final summary detailing all components processed.
The summary SHALL categorize components into:
- Installed components (with their newly installed version)
- Updated components (with previous version and updated version)
- Kept/current components (with current verified version)

#### Scenario: Installation completes with structured summary
- **WHEN** all approved installation and update operations complete
- **THEN** the system displays a final recap listing every processed Scoop application and Mise runtime categorized as installed, updated, or current
