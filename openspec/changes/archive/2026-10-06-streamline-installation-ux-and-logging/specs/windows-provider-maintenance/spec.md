## ADDED Requirements

### Requirement: Streamlined Package Installation Output
During Scoop package installation and update operations, the system SHALL filter internal implementation traces from standard output to maintain a concise console feed.
Filtered output lines SHALL include shim generation and removal, folder linking and unlinking, archive decompression steps, post-install scripts notices, and manifest notes/warnings.
The system SHALL preserve download and progress bars during package retrieval and installation.
All filtered messages, along with standard console messages, SHALL be captured without omission into the workspace execution log file.

#### Scenario: Package installation suppresses shim and linking noise
- **WHEN** Scoop installs or updates an application
- **THEN** internal lines matching shim creation, unlinking, linking, extraction, and manifest notes are suppressed from standard output
- **AND** the package download progress and the final operation status remain visible to the operator
- **AND** the full unfiltered command output is preserved in the workspace log file
