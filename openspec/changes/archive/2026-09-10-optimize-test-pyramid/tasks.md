## 1. Structure and Test Extraction

- [x] 1.1 Create `tests/unit/` directory with test runner and initial test suite for pure helper functions
- [x] 1.2 Implement unit tests for manifest parsing and profile normalization, verifying they complete in < 0.2s
- [x] 1.3 Implement unit tests for preflight Levenshtein distance and prefix matching algorithms

## 2. Gate Integration

- [x] 2.1 Integrate unit test execution into `tests/acceptance/developer_gate.py`
- [x] 2.2 Verify `developer_gate.py` runs both static contract checks and fast unit tests in < 1s

## 3. Documentation

- [x] 3.1 Update `tests/acceptance/README.md` to document the tiered testing strategy (developer gate vs full acceptance gate)
