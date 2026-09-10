## Why

The current acceptance test suite takes over 100 seconds to run on Windows because all 47 tests launch isolated PowerShell and Bash subprocesses inside newly created temporary directories. There is no fast, granular unit test layer for pure functions (manifest validation rules, Levenshtein distance, prefix detection, profile resolution). Restructuring the test pyramid into fast unit tests (< 1s) and end-to-end acceptance tests dramatically improves developer velocity and prevents slow test runs during routine development.

## What Changes

- Add a fast unit test suite targeting pure algorithmic and parsing functions without spawning full shell processes.
- Add tiered test execution commands in `tests/acceptance/` (`--tier fast` / `--tier full`).
- Document the testing strategy and update developer documentation.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None (this is an internal testing structure and developer velocity improvement that does not modify end-user runtime behavior).

## Impact

- `tests/` directory additions.
- Developer workflow documentation in `tests/acceptance/README.md`.
