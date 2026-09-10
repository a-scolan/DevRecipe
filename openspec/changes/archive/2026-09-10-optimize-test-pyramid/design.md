## Context

See proposal.md - Why.
The repository's local gate (`tests/acceptance/quality_gate.py`) and developer gate (`tests/acceptance/developer_gate.py`) provide two extremes:
- `developer_gate.py` runs in < 0.5s but only checks static contracts (TOML parsing, markdown links, syntax).
- `quality_gate.py` executes the entire acceptance test suite, running 47 end-to-end tests that instantiate processes and execute PowerShell/Bash commands, taking ~107s on Windows.

## Goals / Non-Goals

**Goals:**
- Provide a fast unit testing harness (< 2s) for core logic (pure TOML parsing, profile resolution, prefix matching, Levenshtein distance).
- Decouple fast unit tests from slow sandbox acceptance tests.
- Provide a clear tiered CLI option in test runners (`--fast` vs `--full`).

**Non-Goals:**
- Deleting or degrading any existing acceptance tests.
- Changing production behavior in `DevRecipe_windows.ps1` or `DevRecipe_unix.bash`.

## Decisions

### Decision 1: Create a Dedicated `tests/unit/` Directory
- **Rationale**: Isolates lightweight unit tests from the heavyweight sandboxed acceptance suite in `tests/acceptance/`.
- **Alternatives considered**: Adding unit test files inside `tests/acceptance/`. Rejected because `parallel_test_runner.py` auto-discovers all `test_*.py` files in that folder and runs them as sandboxed acceptance tests.

### Decision 2: Integrate Unit Tests into `developer_gate.py`
- **Rationale**: Keeps `developer_gate.py` as the recommended pre-commit / local check that runs instantaneously while providing real logic coverage.

## Risks / Trade-offs

- [Risk] Duplicate test logic between unit tests and acceptance tests.
  → Mitigation: Unit tests focus on algorithmic corner cases (e.g., Levenshtein boundary values, TOML parsing edge cases), while acceptance tests verify external tool invocations and CLI exit codes.
