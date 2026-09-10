# Exact Identifier Removal

## Purpose
Provides safe, narrow uninstallation of exactly declared package identifiers with strict provider preconditions.

## Requirements

### Requirement: Plan-Only Removal by Default
The system SHALL display the planned uninstallation commands without executing them when removal is requested without confirmation.

#### Scenario: Unconfirmed removal prints plan
- **WHEN** the user invokes uninstallation without the confirmation flag
- **THEN** DevRecipe prints the removal plan and exits without mutating provider state

### Requirement: Explicit Confirmation Gate
The system SHALL require an explicit confirmation flag before executing any package or runtime uninstallation commands.

#### Scenario: Confirmed removal executes provider uninstall
- **WHEN** the user invokes uninstallation with the explicit confirmation flag
- **THEN** the exact provider removal command is executed for each requested identifier

### Requirement: Strict Precondition Verification
The system SHALL verify that every requested identifier is declared in the selected manifest profiles and actively listed in the provider inventory before initiating any removal.

#### Scenario: Undeclared or uninstalled identifier aborts entire removal
- **WHEN** any requested identifier is not declared in the selected profile or is not listed by its provider
- **THEN** execution terminates with exit code 2 and no removal commands are executed

### Requirement: Boundary Preservation
The system SHALL limit removal actions to the exact requested packages and runtimes, preserving dependencies, configurations, repositories, and provider bootstraps.

#### Scenario: Conservative provider command used
- **WHEN** uninstallation executes
- **THEN** commands do not include purge, recursive dependency removal, or cleanup flags
