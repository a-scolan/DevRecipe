## MODIFIED Requirements

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
