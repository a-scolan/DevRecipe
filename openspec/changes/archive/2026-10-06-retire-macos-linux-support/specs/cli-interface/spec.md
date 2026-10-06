## REMOVED Requirements

### Requirement: Platform Native Entrypoints
**Reason**: DevRecipe is retiring macOS and Linux support. The multi-platform entrypoint model is replaced by a single dedicated Windows PowerShell entrypoint.
**Migration**: Use `DevRecipe_windows.ps1` for all DevRecipe operations.

### Requirement: Cross-Platform Flag Parity
**Reason**: DevRecipe is now scoped exclusively to Windows PowerShell. Cross-platform CLI parity between PowerShell and Unix Bash is no longer required or supported.
**Migration**: Use Windows PowerShell flag conventions (`-Yes`, `-Review`, `-Containers`, `-Force`, `-SkipPreflight`) directly with `DevRecipe_windows.ps1`.

## ADDED Requirements

### Requirement: Windows Native Entrypoint
The system SHALL provide `DevRecipe_windows.ps1` for Windows PowerShell as the dedicated entrypoint for workstation bootstrapping.

#### Scenario: Windows script executes on Win32NT
- **WHEN** executed on a Windows host
- **THEN** `DevRecipe_windows.ps1` validates prerequisites and operates with Windows native tools

## MODIFIED Requirements

### Requirement: Force Execution Flag
The system SHALL provide an explicit force flag (`-Force`) in Windows PowerShell to pre-approve preflight conflict resolution and avoid interactive prompts when accepted by the operator.

#### Scenario: Force flag pre-approves detected preflight conflicts
- **WHEN** DevRecipe is executed with the force flag and non-fatal preflight conflicts are encountered
- **THEN** all detected entries are marked with decision force without presenting interactive menus or halting non-interactive runs

### Requirement: Preflight Bypass Option
The system SHALL allow operators to explicitly disable preflight conflict checking via a bypass flag (`-SkipPreflight`).

#### Scenario: Preflight scanning skipped when requested
- **WHEN** execution includes `-SkipPreflight`
- **THEN** DevRecipe skips conflict detection scans entirely and proceeds directly to planning or installation
