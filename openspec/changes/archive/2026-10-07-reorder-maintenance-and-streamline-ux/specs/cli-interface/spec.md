## ADDED Requirements

### Requirement: Action Plan Summary
The system SHALL display a concise structured action plan in English describing the operations about to be performed for Scoop applications and Mise runtime environments, specifying the action type (`install`, `uninstall`, or `install and update`).

#### Scenario: Structured action summary before installation
- **WHEN** an installation or update operation is planned
- **THEN** DevRecipe outputs a succinct summary stating "DevRecipe will proceed to [action] Scoop applications:" with the list of packages and versions, followed by "and runtime environments with Mise:" with the list of runtimes and versions
