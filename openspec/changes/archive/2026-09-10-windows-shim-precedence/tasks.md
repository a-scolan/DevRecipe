## 1. Helper Script and cmd.exe AutoRun Support

- [x] 1.1 Implement helper functions in `DevRecipe_windows.ps1` to deploy `%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd` and configure AutoRun in `HKCU:\Software\Microsoft\Command Processor`
- [x] 1.2 Integrate AutoRun registration into the review action confirmation (`Confirm-DevRecipeReviewAction`) and preview/dry-run outputs

## 2. Dual Shim Management (Mise & Scoop) in User PATH and Shell Profiles

- [x] 2.1 Update user environment PATH configuration to ensure `%LOCALAPPDATA%\mise\shims` and `%USERPROFILE%\scoop\shims` are maintained in priority order
- [x] 2.2 Update shell profile hooks to ensure both Mise and Scoop shims are prepended in memory for new shell sessions

## 3. Documentation and Acceptance Testing

- [x] 3.1 Update relevant documentation in `docs/` reflecting the Windows shim precedence and AutoRun mechanism
- [x] 3.2 Run acceptance and unit tests (`python tests/acceptance/developer_gate.py`) to verify zero regressions
