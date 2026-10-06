## MODIFIED Requirements

### Requirement: Windows Installation Provider Maintenance
On every approved standard Windows installation run, the system SHALL update Scoop itself, ensure declared buckets, and refresh its catalogs before performing existing installation detection and version decisions.
It SHALL check and apply available updates to installed Scoop-managed Mise before those decisions.
It SHALL bootstrap Mise when approved selected work requires it, but SHALL NOT install absent unneeded Mise solely for maintenance.
Maintenance SHALL run before existing installations detection and dependent installations or updates.
The system SHALL NOT update unrelated installed applications.
The system SHALL suppress redundant trace noise for already-configured default buckets and already-current applications.
Installed or current selected entries SHALL remain approved maintenance work even when no component installation is needed.

#### Scenario: Existing Scoop serves selected updates
- **WHEN** a standard Windows installation contains approved selected package or Mise actions
- **THEN** Scoop itself is updated, declared buckets are ensured, and catalogs are refreshed before existing installation detection and update decisions use available package versions
- **AND** only selected approved application IDs and installed or required Scoop-managed Mise are eligible for application updates

#### Scenario: Redundant bucket and current-package noise is suppressed
- **WHEN** Scoop maintenance runs on a system where declared buckets and selected applications are already present and current
- **THEN** the system does not print repetitive bucket addition queries or per-application status traces for current packages

#### Scenario: Every selected component is already installed
- **WHEN** an approved standard Windows installation finds every selected component installed
- **THEN** Scoop self-maintenance, bucket checks, and catalog refresh still run before decisions
- **AND** installed Scoop-managed Mise and selected unpinned applications are checked and updated when newer versions are available

#### Scenario: Selected work contains no Mise runtimes
- **WHEN** approved standard Windows work contains only Scoop applications and Scoop-managed Mise is already installed
- **THEN** available Mise provider updates are still applied before decisions
- **AND** absent Mise is not installed solely to maintain it

#### Scenario: Fresh host needs provider bootstrap
- **WHEN** a required provider is absent
- **THEN** the system bootstraps that provider before dependent maintenance or installation
- **AND** it reports an unavailable maintenance prerequisite as an error instead of skipping the refresh

#### Scenario: No approved actions remain
- **WHEN** every selected action was declined by conflict review
- **THEN** the system performs no provider maintenance or application writes
