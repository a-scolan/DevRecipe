# Manifest Management

## Purpose
Validates and parses platform-specific TOML manifests defining declared packages, runtimes, tools, and container bundles for developer workstations.

## Requirements

### Requirement: Manifest Schema Validation
The system SHALL validate the structure and content of platform TOML manifests against schema version 2 rules before executing any recipe operations, recognizing optional platform repository and bucket tables such as `[buckets]` on Windows.

#### Scenario: Valid manifest passes validation
- **WHEN** the user runs manifest validation against a valid TOML manifest
- **THEN** validation succeeds with exit code 0 and reports the manifest contract is valid

#### Scenario: Malformed or missing manifest produces error
- **WHEN** the manifest is missing or contains invalid TOML syntax
- **THEN** validation fails with exit code 2 and lists line-level error diagnostics

### Requirement: Profile Resolution and Normalization
The system SHALL resolve requested profiles, always including the `default` profile, and normalize profile names between CLI conventions and manifest keys.

#### Scenario: Default profile is always included
- **WHEN** the user executes DevRecipe without specifying an optional profile
- **THEN** the `default` profile is selected and its declared entries are processed

#### Scenario: CLI hyphenated profiles map to snake_case manifest keys
- **WHEN** the user requests the `ai-agents` profile via command-line arguments
- **THEN** the profile is normalized to `ai_agents` and entries under `[*.ai_agents.*]` are included

#### Scenario: Unknown profile causes immediate exit
- **WHEN** the user requests an unrecognized profile name
- **THEN** execution terminates with exit code 2 and a list of available profiles

### Requirement: Declaration Integrity
The system SHALL enforce unique declarations within sections and verify that declared items specify non-empty versions.

#### Scenario: Duplicate declaration is rejected
- **WHEN** a manifest contains duplicate package or tool identifiers within the same section
- **THEN** validation terminates with exit code 2 and identifies the duplicate entry

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
