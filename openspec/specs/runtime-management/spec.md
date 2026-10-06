# Runtime Management

## Purpose
Manages language runtimes and command-line developer tools via Mise and configures host shell environment integration.

## Requirements

### Requirement: Mise Tool and Runtime Installation
The system SHALL install declared language runtimes and CLI tools using exact `name@version` specifications through Mise.
On the standard Windows installation route, it SHALL resolve selected approved supported floating requests against available provider versions even when a matching version is installed.
These requests SHALL include `latest`, partial versions, explicit `prefix:` scopes, and backend-supported floating aliases such as `lts`.
The provider SHALL determine selector meaning and matching versions.
The system SHALL install a newly resolved matching version when required and retain older installed versions.
It SHALL preserve the requested selector and SHALL NOT broaden a bounded request to unrestricted `latest`.
It SHALL NOT modify global or project Mise version selection as part of that update.

#### Scenario: Mise installs declared tool version
- **WHEN** a runtime or tool entry such as `node = "latest"` requires installation
- **THEN** DevRecipe executes `mise install node@latest` without modifying global `~/.config/mise/config.toml`

#### Scenario: Windows latest runtime has a newer version
- **WHEN** a selected approved Windows `latest` runtime has an available version newer than its installed version
- **THEN** DevRecipe installs the resolved latest version through Mise
- **AND** it preserves older installed versions and existing global or project version selection

#### Scenario: Exact runtime version remains installed
- **WHEN** an explicitly declared version is already installed
- **THEN** DevRecipe does not upgrade that declaration or replace it with `latest`

#### Scenario: Partial runtime version receives matching updates
- **WHEN** a selected approved request such as `node@22` resolves to a newer matching release
- **THEN** DevRecipe installs that matching release
- **AND** it does not substitute an unrestricted latest major version

#### Scenario: Explicit prefix avoids an exact short-version match
- **WHEN** a selected approved request uses `prefix:22`
- **THEN** DevRecipe delegates prefix resolution to Mise and installs the resolved matching version when absent
- **AND** it does not classify the prefix as a concrete pin

#### Scenario: Floating alias moves to a new release
- **WHEN** a backend-supported floating alias such as Node `lts` resolves to a different release than its installed record
- **THEN** DevRecipe installs the newly resolved release without treating the existing requested alias as proof of freshness

#### Scenario: Windows latest resolution fails
- **WHEN** Mise cannot resolve the available version for a selected `latest` declaration
- **THEN** DevRecipe reports the failure and stops rather than treating any installed version as current

### Requirement: Windows Mise Shims Activation
The system SHALL activate Mise and Scoop shims on Windows with guaranteed precedence by updating the user PATH environment variable, adding shell startup integration hooks, and configuring command processor AutoRun execution.

#### Scenario: User PATH includes Mise shims directory
- **WHEN** Mise runtimes or tools are installed on Windows
- **THEN** `%LOCALAPPDATA%\mise\shims` and `%USERPROFILE%\scoop\shims` are prepended to the user PATH in priority order if not already present

#### Scenario: Shell startup profiles are configured idempotently
- **WHEN** environment activation runs on Windows
- **THEN** shell startup hooks for PowerShell and compatible shells are configured without duplicating existing hook blocks to enforce shim precedence

#### Scenario: Command processor AutoRun is configured idempotently
- **WHEN** environment activation runs on Windows
- **THEN** a user-level script `%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd` is created and registered under `HKCU:\Software\Microsoft\Command Processor\AutoRun` to prepend Mise and Scoop shims to PATH for all `cmd.exe` sessions

### Requirement: Windows Mise Selector Compatibility
The system SHALL distinguish concrete pins, supported floating requests, and unsupported special requests on the standard Windows installation route.
It SHALL NOT implement NPM range semantics for Mise command arguments that do not support them.
It SHALL reject unsupported NPM range arguments and unmanaged special selectors before host mutation, with an actionable error.
It SHALL NOT silently replace an unsupported request with `latest` or treat it as an exact pin.

#### Scenario: Manifest contains an NPM range argument
- **WHEN** a manifest version such as `^22`, `~22`, or `22.*` is unsupported by the Mise command-argument interface
- **THEN** DevRecipe rejects it before host mutation
- **AND** it explains that Mise's package.json range support does not establish support for this manifest argument

#### Scenario: Special source selector has no maintenance policy
- **WHEN** a selected request uses an unmanaged source selector such as `path:`, `system`, or a source reference without an implemented update policy
- **THEN** DevRecipe reports the unsupported maintenance policy before host mutation
- **AND** it does not try to upgrade a local path or arbitrary reference as a released version

### Requirement: Windows Shim Refresh and Node IPC Verification
When Mise maintenance replaces the Windows provider binary or approved selected Node work runs, the system SHALL rebuild existing Mise-owned shims with the verified implementation.
After approved selected Node work, it SHALL test a bounded parent-child IPC exchange through the actual user Node shim.
It SHALL report the Node binary and version selected by that shim separately from the installed manifest version.
It SHALL NOT rewrite existing version selection to make the test pass.

#### Scenario: Mise update replaces an existing Node shim
- **WHEN** a Windows installation updates Mise while a Mise-owned Node shim already exists
- **THEN** DevRecipe rebuilds that shim from the verified updated Mise implementation
- **AND** it does not overwrite unrelated files as Mise-owned shims

#### Scenario: Current Mise still has an old shim
- **WHEN** approved selected Node work uses a fixed Mise release but an existing shim was created by an older release
- **THEN** DevRecipe rebuilds the Mise-owned shim even when no provider update is needed
- **AND** it tests the rebuilt shim rather than accepting the Mise version alone

#### Scenario: Node shim transfers an IPC message
- **WHEN** approved selected Node work completes and the user shim can resolve Node
- **THEN** a parent process sends a message through the shim to a child and receives the matching reply within the test timeout
- **AND** DevRecipe reports the resolved Node binary and version

#### Scenario: Installed latest differs from the active version
- **WHEN** an existing Mise configuration selects a Node version other than the newly installed latest version
- **THEN** DevRecipe reports both versions and explains that installation does not change version selection
- **AND** it does not claim that the latest installed version is active

#### Scenario: Shim resolution or IPC fails
- **WHEN** the shim is missing, cannot resolve Node, exits without a reply, or times out
- **THEN** DevRecipe reports the specific failure and returns non-zero
- **AND** it closes the test channel and terminates only the test processes it created
