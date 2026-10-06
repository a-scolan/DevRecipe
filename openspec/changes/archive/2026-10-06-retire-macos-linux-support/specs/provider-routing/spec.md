## REMOVED Requirements

### Requirement: Platform-Native Package Providers
**Reason**: Non-Windows platform package routing (macOS Homebrew formulae and casks, Linux APT and Flatpak) is retired due to lack of testing and validation environments.
**Migration**: Windows Scoop is now the sole supported package provider via `DevRecipe_windows.ps1`.

## ADDED Requirements

### Requirement: Windows Package Provider Routing
The system SHALL route declared package identifiers to Scoop on Windows, dynamically ensuring all buckets declared under `[buckets]` are configured.

#### Scenario: Windows routes packages to Scoop
- **WHEN** package entries are processed on a Windows host
- **THEN** package installation and inventory commands target Scoop, adding all declared buckets if absent
