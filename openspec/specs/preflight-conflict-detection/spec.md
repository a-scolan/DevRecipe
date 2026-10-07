# Preflight Conflict Detection

## Purpose
Audits local workstation software state and provider inventories prior to mutation to detect existing installations and name collisions.

## Requirements

### Requirement: Provider Inventory Match Elimination
The system SHALL query declared provider inventories and automatically exclude exact matching installed items with `decision=skip-no-action`.
On the standard Windows installation route, installed Scoop entries declared as `latest` and supported floating Mise requests SHALL instead remain eligible for selected update checks.
Their installed state SHALL NOT prove that they are current or create an OS conflict by itself.
Concrete exact versions and the separate container route SHALL keep their existing matching and exclusion behavior.
A partial version or alias SHALL NOT be classified as a concrete exact pin solely because it differs from `latest`.
An inventory record with the same requested floating selector SHALL NOT establish freshness.

#### Scenario: Existing provider item is skipped without prompt
- **WHEN** an entry with a concrete exact version is already listed in the provider inventory with a matching version
- **THEN** it is reported under provider-managed state and removed from the active installation plan

#### Scenario: Installed Windows latest entry remains eligible
- **WHEN** the standard Windows recipe finds a selected `latest` entry in its declared provider inventory
- **THEN** it reports the installed version without claiming freshness
- **AND** it keeps the entry eligible for an update check without an OS conflict prompt

#### Scenario: Installed Windows Mise prefix remains eligible
- **WHEN** a selected Windows Mise request such as `node@22` or `node@prefix:22` has an installed matching version
- **THEN** it remains eligible for resolution of the newest version within that request
- **AND** preflight does not compare the selector literally with a concrete installed version to invent a version conflict

#### Scenario: Installed Windows Mise alias remains eligible
- **WHEN** an installed record reports the same requested alias as a supported selected floating Mise request
- **THEN** preflight reports installed state without claiming that the alias is current
- **AND** the request remains eligible for fresh provider resolution

#### Scenario: Version mismatch triggers conflict state
- **WHEN** an entry is present in the provider inventory with a different concrete exact version than declared
- **THEN** it is flagged as a provider conflict requiring explicit operator decision

#### Scenario: Declined conflict is not updated
- **WHEN** the operator declines an entry because of a provider or OS conflict
- **THEN** that entry is excluded from both installation and update actions

#### Scenario: Unix and container matches retain their behavior
- **WHEN** an installed provider match occurs in the separate Windows container route
- **THEN** it is removed from the active installation plan with `decision=skip-no-action` under the existing route policy

### Requirement: Bounded Local OS Conflict Evidence
The system SHALL query bounded local OS registry, launcher, filesystem, and registration locations for evidence matching declared package names using Levenshtein distance or prefix heuristics, announcing the audit functionally as existing installations detection (`--- EXISTING INSTALLATIONS DETECTION ---`) and presenting findings as detected traces.

#### Scenario: Preflight audit announcement
- **WHEN** preflight conflict detection starts
- **THEN** DevRecipe announces the functional step with `--- EXISTING INSTALLATIONS DETECTION ---` and explains that it is scanning for existing installations to prevent collisions

#### Scenario: High similarity triggers conflict report
- **WHEN** local OS metadata matches a declared package name with similarity score $\ge 90$ or word-boundary prefix
- **THEN** conflict evidence is recorded and displayed under a "Traces found for '<application>':" indicator, limited to a maximum of 3 prioritized evidence records per entry

#### Scenario: Preflight displays interactive progress
- **WHEN** multiple declared packages are scanned during preflight
- **THEN** the system updates a progress indicator reflecting overall scanned items and percentage
- **AND** marks the progress completed when all items have been evaluated

#### Scenario: Candidates without traces are summarized cleanly
- **WHEN** a declared package has no matching local OS traces or provider conflicts
- **THEN** the system omits empty check headers for that candidate from the console output
- **AND** includes only active conflict traces, provider matches, and coverage notes in the preflight summary

### Requirement: Interactive Conflict Decision
The system SHALL present detected conflicts to the operator in an interactive terminal session using a multi-select TUI menu that adapts to compact terminal viewports down to a single visible entry row without cursor buffer overflow, and default to declining unconfirmed installations, unless an explicit force flag has pre-approved installations or preflight is bypassed.

#### Scenario: User forces conflict installation
- **WHEN** the operator explicitly selects or approves a conflicted item
- **THEN** the item remains in the final installation plan with decision force

#### Scenario: User declines conflict installation
- **WHEN** the operator declines or cancels a conflicted item
- **THEN** the item is excluded from the final installation plan with decision decline

#### Scenario: TUI adapts to small terminal viewports
- **WHEN** the console window has constrained vertical space (such as inside small IDE terminal panels)
- **THEN** the interactive multi-select menu calculates a compact viewport without failing or falling back prematurely to text prompts, and clamps cursor coordinates to valid buffer boundaries

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
