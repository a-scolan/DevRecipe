# Preflight Conflict Detection

## Purpose
Audits local workstation software state and provider inventories prior to mutation to detect existing installations and name collisions.

## Requirements

### Requirement: Provider Inventory Match Elimination
The system SHALL query declared provider inventories and automatically exclude exact matching installed items with `decision=skip-no-action`.

#### Scenario: Existing provider item is skipped without prompt
- **WHEN** an entry is already listed in the provider inventory with a matching version
- **THEN** it is reported under provider-managed state and removed from the active installation plan

#### Scenario: Version mismatch triggers conflict state
- **WHEN** an entry is present in the provider inventory with a different version than declared
- **THEN** it is flagged as a provider conflict requiring explicit operator decision

### Requirement: Bounded Local OS Conflict Evidence
The system SHALL query bounded local OS registry, launcher, filesystem, and registration locations for evidence matching declared package names using Levenshtein distance or prefix heuristics, announcing the conflict audit and presenting findings as detected traces.

#### Scenario: Preflight audit announcement
- **WHEN** preflight conflict detection starts
- **THEN** DevRecipe announces that it is scanning requested tools and checking the system for existing traces to prevent installation conflicts

#### Scenario: High similarity triggers conflict report
- **WHEN** local OS metadata matches a declared package name with similarity score $\ge 90$ or word-boundary prefix
- **THEN** conflict evidence is recorded and displayed under a "Traces found for <application>:" indicator, limited to a maximum of 3 prioritized evidence records per entry

### Requirement: Interactive Conflict Decision
The system SHALL present detected conflicts to the operator in an interactive terminal session and default to declining unconfirmed installations, unless an explicit force flag has pre-approved installations or preflight is bypassed.

#### Scenario: User forces conflict installation
- **WHEN** the operator explicitly selects or approves a conflicted item
- **THEN** the item remains in the final installation plan with decision force

#### Scenario: User declines conflict installation
- **WHEN** the operator declines or cancels a conflicted item
- **THEN** the item is excluded from the final installation plan with decision decline

#### Scenario: Force flag pre-empts interactive menu
- **WHEN** execution includes `-Force` or `--force`
- **THEN** detected conflicts are automatically marked with decision force without presenting the interactive selection menu

#### Scenario: Skip preflight completely bypasses scanning
- **WHEN** execution includes `-SkipPreflight` or `--skip-preflight`
- **THEN** conflict auditing is omitted and all declared entries are scheduled directly

### Requirement: Non-Interactive Conflict Safety
The system SHALL abort execution without host mutation when unresolved conflicts are encountered in a non-interactive environment.

#### Scenario: Unattended run halts on conflict
- **WHEN** conflicts are detected and the execution environment is non-interactive
- **THEN** DevRecipe terminates with exit code 3 without performing any installations
