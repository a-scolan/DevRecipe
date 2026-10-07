## ADDED Requirements

### Requirement: Conflict-Safe Global Runtime Activation
The system SHALL automatically activate selected default Mise runtimes globally via `mise use -g <name>@<version>` upon installation on Windows, provided that no pre-existing installation of that runtime is detected on the host.
The system SHALL check whether a pre-existing installation exists for each runtime before attempting global activation.
If a pre-existing installation is detected on the host (via preflight OS evidence, registry uninstall, App Paths, or system PATH command resolution outside Mise shims) or in existing Mise active configuration, the system SHALL skip global activation for that runtime and preserve the existing host installation intact.
The system SHALL NOT execute `mise use -g` for non-runtime CLI tools under tools sections.

#### Scenario: Global activation sets default runtime when no prior installation exists
- **WHEN** standard Windows installation installs a selected default Mise runtime
- **AND** the runtime has no pre-existing installation detected on the host or in Mise
- **THEN** DevRecipe executes `mise use -g <name>@<version>` for that runtime prior to reshim
- **AND** the installed runtime becomes immediately active for the user environment

#### Scenario: Existing host installation prevents global activation to avoid superseding
- **WHEN** standard Windows installation installs a selected default Mise runtime
- **AND** preflight conflict detection, system PATH discovery, or Mise active configuration detects an existing installation for that runtime
- **THEN** DevRecipe skips `mise use -g` for that runtime
- **AND** logs a notice indicating that the pre-existing installation was preserved without being superseded

#### Scenario: Non-runtime Mise tools do not undergo global version activation
- **WHEN** standard Windows installation installs versioned CLI tools under tools sections
- **THEN** DevRecipe installs them via Mise and generates shims without invoking `mise use -g`
