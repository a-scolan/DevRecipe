## MODIFIED Requirements

### Requirement: Manifest Schema Validation
The system SHALL validate the structure and content of platform TOML manifests against schema version 2 rules before executing any recipe operations, recognizing optional platform repository and bucket tables such as `[buckets]` on Windows.

#### Scenario: Valid manifest passes validation
- **WHEN** the user runs manifest validation against a valid TOML manifest
- **THEN** validation succeeds with exit code 0 and reports the manifest contract is valid

#### Scenario: Malformed or missing manifest produces error
- **WHEN** the manifest is missing or contains invalid TOML syntax
- **THEN** validation fails with exit code 2 and lists line-level error diagnostics
