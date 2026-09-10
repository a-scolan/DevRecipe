## MODIFIED Requirements

### Requirement: Interactive Conflict Decision
The system SHALL present detected conflicts to the operator in an interactive terminal session and default to declining unconfirmed installations, unless an explicit force flag has pre-approved installations.

#### Scenario: User forces conflict installation
- **WHEN** the operator explicitly selects or approves a conflicted item
- **THEN** the item remains in the final installation plan with decision force

#### Scenario: User declines conflict installation
- **WHEN** the operator declines or cancels a conflicted item
- **THEN** the item is excluded from the final installation plan with decision decline

#### Scenario: Force flag pre-empts interactive menu
- **WHEN** execution includes `-Force` or `--force`
- **THEN** detected conflicts are automatically marked with decision force without presenting the interactive selection menu
