## 1. CLI Parameter Definitions and Aliases

- [x] 1.1 Add `-Force` parameter in `DevRecipe_windows.ps1` and `--force` / `-f` in `DevRecipe_unix.bash`, verifying with syntax check
- [x] 1.2 Add `-y` alias for `-Yes` in `DevRecipe_windows.ps1` and ensure `--yes` / `-y` parity in both scripts
- [x] 1.3 Add tolerance for `ai_agents` profile in CLI `-Profile` / `--profile` arguments on Windows and Unix

## 2. Preflight Force Integration

- [x] 2.1 Update `Invoke-DevRecipePreflight` in `DevRecipe_windows.ps1` to auto-approve detected conflicts when `-Force` is passed
- [x] 2.2 Update preflight logic in `DevRecipe_unix.bash` to auto-approve detected conflicts when `--force` is passed
- [x] 2.3 Verify preflight non-interactive execution with force flag on simulated conflict

## 3. Documentation and Acceptance Gate

- [x] 3.1 Update CLI usage messages and help blocks in `DevRecipe_windows.ps1` and `DevRecipe_unix.bash`
- [x] 3.2 Update `docs/user-guide.md` and `docs/preflight-and-review.md` with `-Force` / `--force` documentation
- [x] 3.3 Run `python tests/acceptance/developer_gate.py` to verify TOML, markdown links, and syntax
