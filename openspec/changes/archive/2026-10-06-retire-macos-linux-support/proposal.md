## Why

DevRecipe currently includes implementation files, manifests, and documentation for macOS (Homebrew) and Linux (APT + Flatpak) alongside Windows. However, there is no testing infrastructure, active CI, or validation environment available to verify equivalence and functional parity on macOS and Linux.

These features constitute untested dead weight that misleads operators with unverified guarantees and adds ongoing maintenance friction. Retiring macOS and Linux support refocuses DevRecipe on its verified, actively tested Windows PowerShell environment.

## What Changes

- **BREAKING**: Retire and delete the Unix entrypoint `DevRecipe_unix.bash`.
- **BREAKING**: Delete non-Windows manifests `DevRecipe_linux.toml` and `DevRecipe_macos.toml`.
- **BREAKING**: Retire specification requirements for macOS (Homebrew formulae and casks) and Linux (APT and Flatpak) package manager routing.
- **BREAKING**: Retire specification requirements for Unix CLI entrypoints, Unix flag parity, Unix provider conflict matching, and Unix terminal checklist/prompts.
- Remove all Unix test fixtures, execution sandboxes (`run_unix`), and the test class `UnixBootstrapperContractTests` from `tests/acceptance/test_baseline.py`.
- Clean up test helper references to macOS and Linux in `tests/acceptance/manifest_contract.py`, `tests/acceptance/test_parallel_test_runner.py`, and `tests/unit/test_recipe_helpers.py`.
- Update documentation across `README.md` and `docs/` to remove macOS and Linux instructions, CLI examples, package manager references, and matrix entries, establishing DevRecipe explicitly as a Windows-focused workstation bootstrapper.

## Capabilities

### Modified Capabilities

- `cli-interface`: Remove `DevRecipe_unix.bash` entrypoint, host OS detection for Unix, and cross-platform flag parity requirements; scope CLI contract exclusively to `DevRecipe_windows.ps1`.
- `provider-routing`: Remove macOS Homebrew and Linux APT/Flatpak package routing requirements; restrict platform-native provider routing exclusively to Windows Scoop.
- `preflight-conflict-detection`: Remove Unix provider inventory queries and Unix metadata collection requirements; restrict conflict detection rules and evidence presentation to Windows.

## Impact

- Deleted files:
  - `DevRecipe_unix.bash`
  - `DevRecipe_linux.toml`
  - `DevRecipe_macos.toml`
- Modified tests:
  - `tests/acceptance/test_baseline.py` (removes ~580 lines of Unix acceptance tests and sandboxing)
  - `tests/acceptance/manifest_contract.py`
  - `tests/acceptance/test_parallel_test_runner.py`
  - `tests/acceptance/README.md`
  - `tests/unit/test_recipe_helpers.py`
- Modified documentation:
  - `README.md`
  - `docs/ai-agent-use-case.md`
  - `docs/baseline-acceptance-test.md`
  - `docs/container-provider-policy.md`
  - `docs/enterprise-governance.md`
  - `docs/installation.md`
  - `docs/manual-validation.md`
  - `docs/package-matrix.md`
  - `docs/preflight-and-review.md`
  - `docs/quick-start.md`
  - `docs/status-and-removal.md`
  - `docs/user-guide.md`
- Specs updated:
  - `cli-interface`
  - `provider-routing`
  - `preflight-conflict-detection`
