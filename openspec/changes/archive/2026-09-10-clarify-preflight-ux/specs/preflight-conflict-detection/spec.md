## MODIFIED Requirements

### Requirement: Bounded Local OS Conflict Evidence
The system SHALL query bounded local OS registry, launcher, filesystem, and registration locations for evidence matching declared package names using Levenshtein distance or prefix heuristics, announcing the conflict audit and presenting findings as detected traces.

#### Scenario: Preflight audit announcement
- **WHEN** preflight conflict detection starts
- **THEN** DevRecipe announces that it is scanning requested tools and checking the system for existing traces to prevent installation conflicts

#### Scenario: High similarity triggers conflict report
- **WHEN** local OS metadata matches a declared package name with similarity score $\ge 90$ or word-boundary prefix
- **THEN** conflict evidence is recorded and displayed under a "Traces found for <application>:" indicator, limited to a maximum of 3 prioritized evidence records per entry
