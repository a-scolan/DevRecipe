## Why

Windows installation logs currently overwhelm the terminal with excessive internal details from Scoop (including repetitive shims creation, linking/unlinking directories, file extraction, post-install scripts, and manifest notes). At the same time, operators lack a global, percentage-based progress bar tracking overall multi-package progress, and there is no post-execution summary clarifying what was actually installed, updated, or left unchanged. Detailed output is also not archived in a persistent log file within the workspace.

## What Changes

- **Console verbosity reduction**: Suppress internal Scoop and Mise noise on stdout (such as shim creation/removal, unlinking, extracting, post-install scripts, and manifest notes) while preserving interactive download progress bars.
- **Global progress tracking**: Implement an overall progress bar with percentage (`Write-Progress` and console indicator `[X/N - P%]`) that progresses as each Scoop package and Mise runtime is processed.
- **Dedicated workspace logging**: Redirect and archive raw, detailed provider outputs to a dedicated timestamped log file inside the script workspace (`logs/devrecipe-windows-<timestamp>.log`).
- **Post-execution action summary**: At the end of execution, output a concise structured recap of all components processed:
  - Installed applications and runtimes (with installed version)
  - Updated applications and runtimes (with previous $\rightarrow$ new version)
  - Current / unchanged components maintained

## Capabilities

### Modified Capabilities
- `cli-interface`: Add global progress indication with percentage during installation, capture detailed execution traces into a workspace log file, and display an end-of-run summary of treated components.
- `windows-provider-maintenance`: Filter internal provider execution noise on standard output while preserving interactive download feedback and persisting full logs to the workspace.

## Impact

- Modifies `DevRecipe_windows.ps1` (`Invoke-Scoop`, `Invoke-DevRecipeScoopEntry`, `Invoke-DevRecipeMiseEntry`, and main execution flow).
- Generates logs under `logs/` in the workspace root.
- Updates Windows acceptance tests (`test_baseline.py` and `test_windows_maintenance.py`) to verify streamlined console output, global progress tracking, and log file creation.
- Updates documentation (`docs/user-guide.md`, `docs/manual-validation.md`).
