# windows-provider-maintenance Specification

## Purpose
Keeps the providers needed by the standard Windows installation current and prevents use of Node shims without the upstream IPC fix.

## Requirements

### Requirement: Windows Installation Provider Maintenance
On every approved standard Windows installation run, the system SHALL update Scoop itself and refresh its catalogs before resolving selected package updates.
It SHALL check and apply available updates to installed Scoop-managed Mise even when no runtime installation is needed.
It SHALL bootstrap Mise when approved selected work requires it, but SHALL NOT install absent unneeded Mise solely for maintenance.
Maintenance SHALL run after conflict decisions and before dependent installations or updates.
The system SHALL NOT update unrelated installed applications.
Installed or current selected entries SHALL remain approved maintenance work even when no component installation is needed.

#### Scenario: Existing Scoop serves selected updates
- **WHEN** a standard Windows installation contains approved selected package or Mise actions
- **THEN** Scoop itself is updated and its catalogs are refreshed before update decisions use available package versions
- **AND** only selected approved application IDs and installed or required Scoop-managed Mise are eligible for application updates

#### Scenario: Every selected component is already installed
- **WHEN** an approved standard Windows installation finds every selected component installed
- **THEN** Scoop self-maintenance and catalog refresh still run
- **AND** installed Scoop-managed Mise and selected unpinned applications are checked and updated when newer versions are available

#### Scenario: Selected work contains no Mise runtimes
- **WHEN** approved standard Windows work contains only Scoop applications and Scoop-managed Mise is already installed
- **THEN** available Mise provider updates are still applied
- **AND** absent Mise is not installed solely to maintain it

#### Scenario: Fresh host needs provider bootstrap
- **WHEN** a required provider is absent
- **THEN** the system bootstraps that provider before dependent maintenance or installation
- **AND** it reports an unavailable maintenance prerequisite as an error instead of skipping the refresh

#### Scenario: No approved actions remain
- **WHEN** every selected action was declined by conflict review
- **THEN** the system performs no provider maintenance or application writes

### Requirement: Provider-Owned Mise Update
The system SHALL use Scoop to update an installed or required Scoop-managed Mise installation when an update is available on an approved standard Windows installation run.
It SHALL verify the resolved Mise binary and its version after maintenance.
It SHALL NOT replace a Mise binary managed by another provider through Scoop or an unconditional self-update.
An explicit selected Mise version pin SHALL remain binding.

#### Scenario: Scoop manages the resolved Mise binary
- **WHEN** an approved standard Windows installation has installed or required Scoop-managed Mise and Scoop reports an available update
- **THEN** the system updates Mise through Scoop
- **AND** it uses the verified updated binary for dependent actions

#### Scenario: Mise is already current
- **WHEN** refreshed provider metadata establishes that installed Mise is current
- **THEN** the system reports the verified version without reinstalling it

#### Scenario: Explicit Mise version pin prevents an upgrade
- **WHEN** a selected manifest entry fixes Mise to an exact version
- **THEN** the system preserves that version instead of replacing it with the newest release
- **AND** it fails explicitly if the pin cannot satisfy required Node compatibility

#### Scenario: Resolved Mise has another installation source
- **WHEN** the resolved Mise binary is not the Scoop-managed installation
- **THEN** the system reports that automatic provider maintenance is unsupported for that binary
- **AND** it stops before dependent writes with instructions to update or select the intended provider

### Requirement: Fixed Windows Node Shim Version
For approved Windows Node actions, the system SHALL require Mise version 2026.10.1 or later before rebuilding or testing shims.
It SHALL compare release versions rather than version strings lexicographically.
It SHALL NOT accept an unknown version as proof that the fix is present.

#### Scenario: Update supplies the fixed Mise release
- **WHEN** approved Node work starts with an older Scoop-managed Mise and an available fixed release
- **THEN** the system updates Mise before Node work
- **AND** it verifies that the resulting version meets the minimum

#### Scenario: Provider cannot supply the fixed release
- **WHEN** the verified Mise version remains below 2026.10.1 after maintenance
- **THEN** execution fails before Node installation and shim activation
- **AND** the error identifies the detected version and required minimum

### Requirement: Maintenance Respects Execution Modes
The system SHALL preserve the existing non-mutating modes and review checkpoints.
Validation and listing SHALL remain manifest-only.
Status and removal SHALL NOT trigger new provider refreshes or updates.
Dry run SHALL show conditional maintenance and update actions without executing them.
Review SHALL require approval before each maintenance or update write.
Skipping preflight SHALL bypass conflict scanning only, not update checks or compatibility checks.

#### Scenario: Dry run uses potentially stale catalogs
- **WHEN** dry run runs before the Scoop catalogs are refreshed
- **THEN** its output marks update decisions as provisional
- **AND** no catalog, provider, package, shim, PATH, or shell configuration is changed

#### Scenario: Review refuses a provider update
- **WHEN** review refuses a required maintenance action
- **THEN** execution stops before that action and its dependent writes

#### Scenario: Provider or network query fails
- **WHEN** a required refresh, inventory query, update, or version check fails
- **THEN** execution reports the failed operation and returns non-zero
- **AND** it does not report the affected component as current

### Requirement: Streamlined Package Installation Output
During Scoop package installation and update operations, the system SHALL filter internal implementation traces from standard output to maintain a concise console feed.
Filtered output lines SHALL include shim generation and removal, folder linking and unlinking, archive decompression steps, post-install scripts notices, and manifest notes/warnings.
The system SHALL preserve download and progress bars during package retrieval and installation.
All filtered messages, along with standard console messages, SHALL be captured without omission into the workspace execution log file.

#### Scenario: Package installation suppresses shim and linking noise
- **WHEN** Scoop installs or updates an application
- **THEN** internal lines matching shim creation, unlinking, linking, extraction, and manifest notes are suppressed from standard output
- **AND** the package download progress and the final operation status remain visible to the operator
- **AND** the full unfiltered command output is preserved in the workspace log file
