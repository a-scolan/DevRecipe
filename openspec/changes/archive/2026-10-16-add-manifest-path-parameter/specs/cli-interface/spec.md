## ADDED Requirements

### Requirement: Explicit Manifest Path Option
The system SHALL provide a `-Manifest <path>` option in `DevRecipe_windows.ps1` that selects the TOML manifest used by the requested mode. The option SHALL NOT count as a mode switch and SHALL be combinable with validate, list, status, dry run, installation, uninstall, and container modes.
When a relative path is given, the system SHALL resolve it against the current working directory.
When `-Manifest` is omitted, the system SHALL read `DevRecipe_windows.toml` from the folder that contains the script.

#### Scenario: Relative manifest path is resolved from the current directory
- **WHEN** the user runs `DevRecipe_windows.ps1 -Manifest .\test.toml -Validate` from a folder that contains `test.toml`
- **THEN** validation reads `test.toml` from that folder and exits with code 0 if the manifest is valid

#### Scenario: Absolute manifest path is used as given
- **WHEN** the user runs `DevRecipe_windows.ps1 -Manifest C:\recipes\team.toml -List`
- **THEN** list mode reads `C:\recipes\team.toml` and does not read the default manifest

#### Scenario: Default manifest is used without the option
- **WHEN** the user runs `DevRecipe_windows.ps1 -Validate` without `-Manifest`
- **THEN** validation reads `DevRecipe_windows.toml` from the script folder, as before

#### Scenario: Missing manifest path fails before any change
- **WHEN** the user passes a `-Manifest` path that does not exist
- **THEN** the script reports a manifest validation error that names the path and exits with code 2
- **AND** no provider command is run and no host state is changed

#### Scenario: Manifest option combines with installation planning
- **WHEN** the user runs `DevRecipe_windows.ps1 -Manifest .\test.toml -DryRun`
- **THEN** the dry-run plan lists only the entries declared in `.\test.toml` for the selected profiles
