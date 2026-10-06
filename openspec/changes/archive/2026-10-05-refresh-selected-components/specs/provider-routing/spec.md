## ADDED Requirements

### Requirement: Selected Windows Package Updates
In the standard Windows installation, the system SHALL install missing selected package IDs and update installed selected IDs declared as `latest` when the refreshed Scoop catalog offers a newer version.
It SHALL pass the selected identifiers verbatim and preserve explicit version handling.
It SHALL NOT run a wildcard application update.
It SHALL report installed, current, updated, and failed outcomes without conflating them.
Every already-installed eligible package in the selected approved profiles SHALL participate in maintenance on each standard Windows installation run.
Installed state SHALL NOT remove an eligible package from that maintenance scope.

#### Scenario: Selected installed package has an update
- **WHEN** a selected approved `latest` package is installed and its refreshed Scoop catalog offers an update
- **THEN** Scoop receives an update action for that exact package ID
- **AND** unrelated installed packages are not updated

#### Scenario: Repeated installation maintains the entire selected list
- **WHEN** all approved selected Scoop packages are already installed
- **THEN** every selected package declared as `latest` is checked against refreshed metadata
- **AND** each available update is applied to its exact ID without requiring a missing package to trigger maintenance
- **AND** concrete version pins remain unchanged

#### Scenario: Selected package is current
- **WHEN** the refreshed provider inventory and catalog establish that a selected package is current
- **THEN** the system reports that result without reinstalling the package

#### Scenario: Package inventory is unavailable
- **WHEN** the system cannot establish whether a selected package is installed or current
- **THEN** it reports an error instead of guessing install, skip, or update

## MODIFIED Requirements

### Requirement: Non-Mutating Dry Run Plan
The system SHALL generate and display the planned sequence of provider commands without mutating the host system.
For the standard Windows installation, this plan SHALL include provider maintenance, selected update checks, and conditional update actions.
It SHALL identify decisions that depend on a future catalog refresh.

#### Scenario: Dry run produces full execution plan without side effects
- **WHEN** the user executes DevRecipe with the dry-run option
- **THEN** the recipe performs preflight audit and outputs the exact commands that would be executed, without running mutating commands

#### Scenario: Windows dry run includes installed latest entries
- **WHEN** a standard Windows dry run finds installed selected entries declared as `latest`
- **THEN** the plan includes their update checks rather than dropping them as no-action entries
- **AND** it shows conditional exact-ID updates and provider maintenance without performing them
