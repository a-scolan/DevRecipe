## ADDED Requirements

### Requirement: Selectable Manifest Source
The system SHALL read every manifest-dependent operation (validation, profile resolution, listing, status, dry run, installation, uninstall, and container bundle selection) from the manifest file selected by the operator. The selected file is the manifest that the operator names with `-Manifest`, or `DevRecipe_windows.toml` in the script folder when no path is given.
The system SHALL apply the same schema version 2 validation, profile resolution, and declaration integrity rules to any selected file.
The system SHALL NOT read the default manifest when another manifest is selected.

#### Scenario: Selected manifest is the only manifest read
- **WHEN** the user runs a listing with `-Manifest .\test.toml` while the default `DevRecipe_windows.toml` also exists
- **THEN** only the entries declared in `.\test.toml` are listed

#### Scenario: Selected manifest goes through the same validation
- **WHEN** the user selects a manifest that omits `[metadata] schema_version = 2` or declares a duplicate identifier
- **THEN** validation fails with exit code 2 and lists line-level diagnostics for the selected file

#### Scenario: Container bundle reads the selected manifest
- **WHEN** the user runs the container bundle with `-Manifest .\test.toml -DryRun`
- **THEN** the container packages are read from the `[containers.default.os.*]` sections of `.\test.toml`
