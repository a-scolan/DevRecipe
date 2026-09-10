# Runtime Management

## Purpose
Manages language runtimes and command-line developer tools via Mise and configures host shell environment integration.

## Requirements

### Requirement: Mise Tool and Runtime Installation
The system SHALL install declared language runtimes and CLI tools using exact `name@version` specifications through Mise.

#### Scenario: Mise installs declared tool version
- **WHEN** a runtime or tool entry such as `node = "latest"` is processed
- **THEN** DevRecipe executes `mise install node@latest` without modifying global `~/.config/mise/config.toml`

### Requirement: Windows Mise Shims Activation
The system SHALL activate Mise shims on Windows by updating the user PATH environment variable and adding shell startup integration hooks.

#### Scenario: User PATH includes Mise shims directory
- **WHEN** Mise runtimes or tools are installed on Windows
- **THEN** `%LOCALAPPDATA%\mise\shims` is appended to the user PATH if not already present

#### Scenario: Shell startup profiles are configured idempotently
- **WHEN** Mise installation completes on Windows
- **THEN** shell startup hooks for PowerShell and compatible shells are configured without duplicating existing hook blocks
