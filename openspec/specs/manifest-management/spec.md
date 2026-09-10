# Manifest Management

## Purpose
Validates and parses platform-specific TOML manifests defining declared packages, runtimes, tools, and container bundles for developer workstations.

## Requirements

### Requirement: Manifest Schema Validation
The system SHALL validate the structure and content of platform TOML manifests against schema version 2 rules before executing any recipe operations.

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
