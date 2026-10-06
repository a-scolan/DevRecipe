## 1. Manifest and Implementation Deletion

- [x] 1.1 Delete `DevRecipe_unix.bash` and verify the file is removed from the repository root
- [x] 1.2 Delete `DevRecipe_linux.toml` and `DevRecipe_macos.toml` and verify neither file remains in the repository root

## 2. Test Suite Cleanup and Realignment

- [x] 2.1 Update `tests/acceptance/manifest_contract.py` to target only `DevRecipe_windows.toml` and verify `py -m unittest tests/acceptance/manifest_contract.py` passes
- [x] 2.2 Remove `UnixBootstrapperContractTests`, `unix_runtime_helpers`, and `run_unix` from `tests/acceptance/test_baseline.py` and verify `py -m unittest tests/acceptance/test_baseline.py` passes
- [x] 2.3 Update mock test names in `tests/acceptance/test_parallel_test_runner.py` to reference active Windows tests and verify `py -m unittest tests/acceptance/test_parallel_test_runner.py` passes
- [x] 2.4 Update platform fixtures in `tests/unit/test_recipe_helpers.py` and verify unit tests pass via `py -m unittest discover tests/unit`
- [x] 2.5 Update `tests/acceptance/README.md` to remove Unix sandbox descriptions and verify documentation accuracy

## 3. Documentation Modernization

- [x] 3.1 Update `README.md` to present DevRecipe strictly as a Windows workstation bootstrapper
- [x] 3.2 Update `docs/quick-start.md`, `docs/installation.md`, and `docs/user-guide.md` to remove Unix bash commands, tables, and cask/flatpak syntax
- [x] 3.3 Update `docs/package-matrix.md`, `docs/status-and-removal.md`, and `docs/preflight-and-review.md` to remove macOS/Linux columns and CLI options
- [x] 3.4 Update `docs/manual-validation.md`, `docs/baseline-acceptance-test.md`, `docs/container-provider-policy.md`, `docs/enterprise-governance.md`, and `docs/ai-agent-use-case.md` to remove non-Windows operating system references
- [x] 3.5 Execute `py tests/acceptance/markdown_links.py` and verify that all internal markdown links and cross-references resolve without errors

## 4. Verification and Quality Gate

- [x] 4.1 Run the comprehensive quality gate with `py tests/acceptance/quality_gate.py` and verify that all remaining Windows acceptance and contract tests pass
- [x] 4.2 Validate the OpenSpec change using `openspec validate retire-macos-linux-support --strict` and verify that all change artifacts adhere to schema standards
