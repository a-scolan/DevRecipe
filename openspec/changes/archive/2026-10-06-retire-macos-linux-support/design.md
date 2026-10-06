## Context

See `proposal.md` for background and motivation. DevRecipe originally envisioned multi-platform support across Windows, macOS, and Linux. In practice, development and testing have focused almost exclusively on Windows PowerShell 5.1 with Scoop, Mise, and Podman. The Unix script (`DevRecipe_unix.bash`), macOS manifest (`DevRecipe_macos.toml`), and Linux manifest (`DevRecipe_linux.toml`) lack continuous integration, live end-to-end testing, and operational validation.

This design establishes the inventory of code, tests, documentation, and specs to remove or update, ensuring that DevRecipe transitions cleanly into an explicitly Windows-focused codebase.

## Goals / Non-Goals

**Goals:**
- Provide a complete inventory of all files and subsystems to be removed or updated.
- Completely remove unmaintained Unix script implementation (`DevRecipe_unix.bash`) and non-Windows manifests (`DevRecipe_linux.toml`, `DevRecipe_macos.toml`).
- Retain only Windows test cases in the acceptance test suite (`tests/acceptance/test_baseline.py`), removing Unix sandbox execution fixtures and mocks.
- Restrict manifest contract validation (`tests/acceptance/manifest_contract.py`) exclusively to Windows.
- Update documentation across `README.md` and `docs/` to present DevRecipe solely as a Windows workstation bootstrapper.
- Update OpenSpec specifications to retire Unix entrypoints, cross-platform flag parity, and non-Windows package manager routing.

**Non-Goals:**
- Retain deprecated shim or stub scripts for `DevRecipe_unix.bash` (the user explicitly requested outright removal of untested implementations).
- Change Windows PowerShell behavior, Windows Scoop bucket handling, Windows Mise shims, or Windows Podman container policies.
- Introduce new features or refactor Windows implementation logic during this change.

## Inventory of Affected Components

### 1. Deleted Implementations & Manifests
- `DevRecipe_unix.bash`: Standalone Bash 4+ script containing all macOS (Homebrew) and Linux (APT/Flatpak) bootstrapping, preflight scanning, menuing, and removal logic (2,185 lines).
- `DevRecipe_linux.toml`: Linux manifest declaring APT and Flatpak packages.
- `DevRecipe_macos.toml`: macOS manifest declaring Homebrew formulae and casks.

### 2. Modified Test Suite
- `tests/acceptance/test_baseline.py`:
  - Remove `unix_runtime_helpers()` and `run_unix()` methods from `RecipeSandbox`.
  - Remove entire `UnixBootstrapperContractTests` class (tests for Unix portability, list, dry-run, status, preflight, interactive checklist, review rejection, and removal).
  - Update `test_public_runtime_messages_do_not_regress_to_french` to inspect only `DevRecipe_windows.ps1`.
- `tests/acceptance/manifest_contract.py`:
  - Update `EXPECTED_PLATFORM_MANIFESTS` to contain only `("windows", "DevRecipe_windows.toml")`.
  - Update `EXPECTED_PACKAGES_SECTIONS` to remove `macos` (`{"os", "cask"}`) and `linux` (`{"os", "flatpak"}`), keeping only `windows`.
- `tests/acceptance/test_parallel_test_runner.py`:
  - Update test names in discovery mock tests to reference Windows test methods rather than `UnixBootstrapperContractTests`.
- `tests/acceptance/README.md`:
  - Remove Bash/Unix environment requirements and descriptions of Unix sandbox execution.
- `tests/unit/test_recipe_helpers.py`:
  - Update any multi-platform fixture expectations to Windows only.

### 3. Modified Specifications (OpenSpec)
- `specs/cli-interface/spec.md`:
  - Modify `Requirement: Platform Native Entrypoints` to designate `DevRecipe_windows.ps1` as the sole entrypoint.
  - Modify `Requirement: Force Execution Flag` and `Requirement: Preflight Bypass Option` to reference only Windows CLI flags (`-Force`, `-SkipPreflight`).
  - Remove `Requirement: Cross-Platform Flag Parity`.
- `specs/provider-routing/spec.md`:
  - Modify `Requirement: Platform-Native Package Providers` to route only to Scoop on Windows.
- `specs/preflight-conflict-detection/spec.md`:
  - Modify `Requirement: Provider Inventory Match Elimination` and `Requirement: Interactive Conflict Decision` to remove Unix inventory queries and Unix menu behaviors.

### 4. Modified Documentation
- `README.md`: Scope product positioning, quick commands, and architecture diagrams exclusively to Windows.
- `docs/quick-start.md`: Remove macOS/Linux tabs, table rows, and bash commands.
- `docs/installation.md`: Remove macOS and Ubuntu/Debian prerequisites, commands, and container rows.
- `docs/user-guide.md`: Remove bash commands, cask/flatpak package definitions, and Unix flag aliases.
- `docs/package-matrix.md`: Remove macOS and Linux columns and Homebrew/APT/Flatpak notes.
- `docs/preflight-and-review.md`: Remove Unix preflight scanning notes, Unix terminal menu details, and `--force` / `--skip-preflight` bash flags.
- `docs/status-and-removal.md`: Remove Homebrew and Linux provider query tables and removal examples.
- `docs/manual-validation.md`: Remove Unix test runs and checklist validation procedures.
- `docs/container-provider-policy.md`: Remove macOS and Linux machine notes, focusing on WSL 2 vs Hyper-V on Windows.
- `docs/enterprise-governance.md`: Remove macOS and Linux governance rows (APT sudo, Flatpak remotes, Homebrew ownership).
- `docs/ai-agent-use-case.md`: Remove Linux APT repository setup for Claude Desktop beta and Unix bash commands.
- `docs/baseline-acceptance-test.md`: Remove Unix fixture documentation.

## Decisions

### Decision 1: Immediate Deletion vs. Deprecation Stub
- **Choice**: Immediately delete `DevRecipe_unix.bash`, `DevRecipe_linux.toml`, and `DevRecipe_macos.toml`.
- **Rationale**: The user explicitly requested removing implementations that are neither tested nor validated. Keeping placeholder stubs would preserve confusing artifacts in the repository root.
- **Alternative considered**: Keeping a stub `DevRecipe_unix.bash` that prints "DevRecipe now only supports Windows". Rejected because operators on Unix cannot run DevRecipe anyway, and clean removal leaves no dead files in the workspace.

### Decision 2: Manifest Contract Scope
- **Choice**: Enforce manifest schema contract only against `DevRecipe_windows.toml`.
- **Rationale**: With Linux and macOS manifests deleted, `manifest_contract.py` should strictly validate the remaining active manifest.
- **Alternative considered**: Retaining schema validation rules for `cask` and `flatpak` in case they return in the future. Rejected because unused schema definitions create maintenance debt.

### Decision 3: Acceptance Test Suite Pruning
- **Choice**: Remove all Unix-specific test cases and helper sandboxing functions in `tests/acceptance/test_baseline.py`.
- **Rationale**: The test suite currently mocks bash and unix commands (`run_unix`). Running synthetic unit/acceptance tests against a deleted script is nonsensical. Pruning these tests will make `py -m unittest` faster and 100% focused on Windows behavior.
- **Alternative considered**: Moving Unix tests to an archive directory. Rejected because the code they test is being deleted.

## Risks / Trade-offs

- **[Risk] Existing documentation links or external references to Unix files break** → Mitigation: Search and update all internal markdown links and cross-references across `docs/` and `README.md` to ensure no dead links remain.
- **[Risk] Regressions in test runner execution** → Mitigation: Ensure `tests/acceptance/test_parallel_test_runner.py` and `tests/acceptance/quality_gate.py` pass without error after removing `UnixBootstrapperContractTests`.
