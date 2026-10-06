## MODIFIED Requirements

### Requirement: Provider Inventory Match Elimination
The system SHALL query declared provider inventories and automatically exclude exact matching installed items with `decision=skip-no-action`.
On the standard Windows installation route, installed Scoop entries declared as `latest` and supported floating Mise requests SHALL instead remain eligible for selected update checks.
Their installed state SHALL NOT prove that they are current or create an OS conflict by itself.
Concrete exact versions and Unix or container routes SHALL keep their existing matching and exclusion behavior.
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
- **WHEN** an installed provider match occurs on Unix or in the separate Windows container route
- **THEN** it is removed from the active installation plan with `decision=skip-no-action` under the existing route policy
