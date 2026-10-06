## MODIFIED Requirements

### Requirement: Bounded Local OS Conflict Evidence
The system SHALL query bounded local OS registry, launcher, filesystem, and registration locations for evidence matching declared package names using Levenshtein distance or prefix heuristics, announcing the conflict audit and presenting findings as detected traces.
Candidate entries SHALL be evaluated concurrently across candidate installation items against collected local OS metadata.
During preflight analysis, the system SHALL display interactive progress indicators reporting step count and completion percentage.
The conflict detection output SHALL present a consolidated summary of detected traces, provider-managed states, and coverage notes, omitting empty check headers for candidates without findings.

#### Scenario: Preflight audit announcement
- **WHEN** preflight conflict detection starts
- **THEN** DevRecipe announces that it is scanning requested tools and checking the system for existing traces to prevent installation conflicts

#### Scenario: High similarity triggers conflict report
- **WHEN** local OS metadata matches a declared package name with similarity score $\ge 90$ or word-boundary prefix
- **THEN** conflict evidence is recorded and displayed under a "Traces found for <application>:" indicator, limited to a maximum of 3 prioritized evidence records per entry

#### Scenario: Preflight displays interactive progress
- **WHEN** multiple declared packages are scanned during preflight
- **THEN** the system updates a progress indicator reflecting overall scanned items and percentage
- **AND** marks the progress completed when all items have been evaluated

#### Scenario: Candidates without traces are summarized cleanly
- **WHEN** a declared package has no matching local OS traces or provider conflicts
- **THEN** the system omits empty check headers for that candidate from the console output
- **AND** includes only active conflict traces, provider matches, and coverage notes in the preflight summary
