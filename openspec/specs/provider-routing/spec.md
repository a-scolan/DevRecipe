# Provider Routing

## Purpose
Routes declared package identifiers to native operating-system package managers and verifies raw identifier integrity without application configuration.

## Requirements

### Requirement: Platform-Native Package Providers
The system SHALL route declared package identifiers to the designated native package manager for the host platform: Scoop on Windows (dynamically ensuring all buckets declared under `[buckets]` are configured), Homebrew (formulae and casks) on macOS, and APT with user-scoped Flatpak on Ubuntu/Debian.

#### Scenario: Windows routes packages to Scoop
- **WHEN** package entries are processed on a Windows host
- **THEN** package installation and inventory commands target Scoop, adding all declared buckets if absent

#### Scenario: macOS routes formulae and casks to Homebrew
- **WHEN** package entries are processed on a macOS host
- **THEN** formula entries target `brew install` and cask entries target `brew install --cask`

#### Scenario: Linux routes packages to APT and Flatpak
- **WHEN** package entries are processed on an Ubuntu or Debian host
- **THEN** OS packages target APT (`sudo apt install -y`) and user desktop applications target Flatpak (`flatpak install --user -y`)

### Requirement: Raw Identifier Forwarding
The system SHALL forward declared identifiers verbatim to native providers without guessing executable names, synthesizing package prefixes, or generating application configurations.

#### Scenario: Package IDs forwarded without modification
- **WHEN** a declared package such as `nginx` or `ripgrep` is installed
- **THEN** the exact declared identifier is passed to the native provider without generating local service files or custom configuration

### Requirement: Non-Mutating Manifest Listing
The system SHALL support listing declared items from the manifest without calling external package providers or network services.

#### Scenario: Manifest list mode reads only manifest
- **WHEN** the user runs DevRecipe with the list option
- **THEN** all declared packages, runtimes, and tools for selected profiles are printed without invoking provider binaries

### Requirement: Non-Mutating Dry Run Plan
The system SHALL generate and display the planned sequence of provider commands without mutating the host system.

#### Scenario: Dry run produces full execution plan without side effects
- **WHEN** the user executes DevRecipe with the dry-run option
- **THEN** the recipe performs preflight audit and outputs the exact commands that would be executed, without running mutating commands
