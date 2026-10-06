## ADDED Requirements

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
