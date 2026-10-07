## 1. Documentation of PATH Precedence Limitations

- [x] 1.1 In `docs/installation.md`, add a dedicated subsection detailing the Windows `System PATH` (Machine) vs `User PATH` precedence limitation, explaining how GUI applications and desktop launchers (like VS Code) inherit the system path before user shims, and provide operator workarounds.
- [x] 1.2 In `docs/package-matrix.md` and `docs/user-guide.md`, document the `System PATH` precedence behavior and describe the automatic conflict-safe global activation of default runtimes.

## 2. Conflict-Safe Global Runtime Activation Implementation

- [x] 2.1 In `DevRecipe_windows.ps1`, implement helper function `Test-DevRecipeExistingRuntimeInstallation` that verifies whether a pre-existing installation or active configuration exists for a given runtime by inspecting preflight OS evidence, checking executable resolution outside Mise/Scoop shims via `Get-Command`, and querying `mise current`.
- [x] 2.2 In `DevRecipe_windows.ps1`, within the installation block after `mise install` loops and before `mise reshim`, execute `mise use -g <name>@<version>` for each approved default runtime when no pre-existing installation was detected.
- [x] 2.3 Log clear, informative notices for each runtime indicating whether global activation was applied or skipped to prevent superseding an existing installation.
- [x] 2.4 Register `mise use -g` checkpoints with `Confirm-DevRecipeReviewAction` when interactive `-Review` is enabled.

## 3. Verification and Quality Gates

- [x] 3.1 Add test coverage in `tests/acceptance/test_baseline.py` covering conflict-safe global activation behavior and documentation references.
- [x] 3.2 Run acceptance tests with `python tests/acceptance/parallel_test_runner.py` to ensure all tests pass cleanly.
- [x] 3.3 Validate the change with `openspec validate optional-global-runtime-activation --strict`.
