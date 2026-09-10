## 1. CLI Parameter Enhancements

- [x] 1.1 Add `-SkipPreflight` parameter to `DevRecipe_windows.ps1` and `--skip-preflight` to `DevRecipe_unix.bash`
- [x] 1.2 Add aliases `-DockerAlias` for `-EnableDockerAlias` and `-FeaturesOnly` for `-ContainerFeatureSetupOnly` in `DevRecipe_windows.ps1`
- [x] 1.3 Update usage messages in both scripts to reflect new clean parameters

## 2. Preflight Bypass Implementation

- [x] 2.1 Update `DevRecipe_windows.ps1` to skip `Invoke-DevRecipePreflight` when `-SkipPreflight` is passed
- [x] 2.2 Update `DevRecipe_unix.bash` to skip preflight execution when `--skip-preflight` is passed

## 3. Documentation Rewrite in Simple English

- [x] 3.1 Rewrite `README.md` and `docs/quick-start.md` in concise Simple English
- [x] 3.2 Rewrite `docs/installation.md` and `docs/user-guide.md` in concise Simple English
- [x] 3.3 Rewrite `docs/preflight-and-review.md` and `docs/status-and-removal.md` in concise Simple English
- [x] 3.4 Rewrite remaining files in `docs/` (`container-provider-policy.md`, `package-matrix.md`, `ai-agent-use-case.md`, `enterprise-governance.md`, `manual-validation.md`, `baseline-acceptance-test.md`, `roadmap.md`)

## 4. Verification

- [x] 4.1 Run `python tests/acceptance/developer_gate.py` to ensure zero Markdown link or syntax errors
