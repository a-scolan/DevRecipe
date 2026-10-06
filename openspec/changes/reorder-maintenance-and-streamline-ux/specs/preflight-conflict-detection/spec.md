## MODIFIED Requirements

### Requirement: Bounded Local OS Conflict Evidence
The system SHALL query bounded local OS registry, launcher, filesystem, and registration locations for evidence matching declared package names using Levenshtein distance or prefix heuristics, announcing the audit functionally as existing installations detection (`--- EXISTING INSTALLATIONS DETECTION ---`) and presenting findings as detected traces.

#### Scenario: Preflight audit announcement
- **WHEN** preflight conflict detection starts
- **THEN** DevRecipe announces the functional step with `--- EXISTING INSTALLATIONS DETECTION ---` and explains that it is scanning for existing installations to prevent collisions

#### Scenario: High similarity triggers conflict report
- **WHEN** local OS metadata matches a declared package name with similarity score $\ge 90$ or word-boundary prefix
- **THEN** conflict evidence is recorded and displayed under a "Traces found for '<application>':" indicator, limited to a maximum of 3 prioritized evidence records per entry

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
