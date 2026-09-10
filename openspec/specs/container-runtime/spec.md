# Container Runtime

## Purpose
Provisions an opt-in local container development environment using Podman, Podman Desktop, and companion tools with platform virtualization policies.

## Requirements

### Requirement: Windows Machine Provider Evaluation
The system SHALL evaluate local virtualization state according to established policy: preserve existing Podman machine, preserve WSL 2 distribution with working Podman, prefer WSL 2 over Hyper-V, and enable features only when needed.

#### Scenario: Existing machine is preserved
- **WHEN** an existing Podman machine or WSL 2 Podman environment is detected on Windows
- **THEN** setup preserves the existing machine and does not alter virtualization features

#### Scenario: WSL 2 selected when both ready
- **WHEN** a new machine is needed and both WSL 2 and Hyper-V are ready
- **THEN** DevRecipe selects WSL 2 as the machine provider

### Requirement: Elevation and Reboot Boundary
The system SHALL request elevated privileges only for Windows optional feature configuration and halt with guidance if a system restart is required.

#### Scenario: Elevation required for feature activation
- **WHEN** required Windows virtualization features are not enabled
- **THEN** DevRecipe initiates an elevated process to enable them and prompts for reboot if required before package installation

### Requirement: Container Package Installation
The system SHALL install container tools from the manifest only after virtualization prerequisites are satisfied.

#### Scenario: Container bundle packages installed
- **WHEN** container setup prerequisites are satisfied without requiring an immediate reboot
- **THEN** Podman, Podman Desktop, and docker-compose are installed via the platform package manager

### Requirement: Optional Docker Alias Compatibility
The system SHALL provide an opt-in PowerShell profile function forwarding `docker` commands to `podman` when Docker is not already present on the system.

#### Scenario: Docker alias configured when requested
- **WHEN** container installation is requested with the Docker alias option and `docker` does not resolve
- **THEN** a PowerShell profile wrapper forwarding `docker` to `podman` is created
