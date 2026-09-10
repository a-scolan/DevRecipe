# Human Review

## Purpose
Requires explicit operator approval for each planned host mutation in an interactive terminal session prior to execution.

## Requirements

### Requirement: Interactive Write Checkpoint
The system SHALL present a discrete approval checkpoint before executing any host-mutating command when review mode is enabled.

#### Scenario: Checkpoint displays action details
- **WHEN** an action is reached in review mode
- **THEN** DevRecipe displays the command, required privilege level, target/source, and expected effect before prompting

#### Scenario: Individual approval permits execution
- **WHEN** the operator approves an action with `y` or `yes`
- **THEN** the command is executed and the next action checkpoint is presented

### Requirement: Session-Wide Approval Option
The system SHALL support approving all remaining actions in the active session with a single confirmation.

#### Scenario: Batch approval continues without further prompts
- **WHEN** the operator enters `A` at an action checkpoint
- **THEN** the current action and all remaining actions in the session are executed without further prompts

### Requirement: Terminal Requirement and Rejection Safety
The system SHALL abort execution immediately if an action is rejected or if review mode is requested in a non-interactive terminal.

#### Scenario: Rejection halts execution
- **WHEN** the operator declines an action checkpoint
- **THEN** execution terminates with exit code 3 and remaining actions are marked unreviewed

#### Scenario: Non-interactive session is blocked
- **WHEN** review mode is invoked without an interactive TTY
- **THEN** execution terminates with exit code 3 before any mutation is attempted
