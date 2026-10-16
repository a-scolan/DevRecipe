## Context

`DevRecipe_windows.ps1` sets `$TomlPath = Join-Path $PSScriptRoot "DevRecipe_windows.toml"` once, at script start (line 29). Every manifest reader uses that single variable: `Test-DevRecipeManifest`, `Get-Content -LiteralPath $TomlPath` for list, status, and install, the container package reader, and the "Valid manifest" message. The script has no parameter that changes this path. Missing files are already reported by `Test-DevRecipeManifest` as `file not found`, with exit code 2. See proposal.md for motivation and specs/ for the requirements.

## Goals / Non-Goals

**Goals:**
- One optional parameter selects the manifest for every mode, without duplicating the script.
- The default behavior and default manifest location stay unchanged when the parameter is omitted.
- A missing path is reported by the existing validation path, before any provider call.

**Non-Goals:**
- No multiple manifests per run, no manifest merging, and no manifest discovery by profile name.
- No change to validation rules, profile rules, preflight, or provider commands.
- No move of the logs folder. Logs stay in `logs/` next to the script (see Decisions).

## Decisions

**Parameter name `-Manifest <string>`.** It matches the wording used in the docs ("platform manifest") and does not reuse the internal name `ManifestPath`, which is already the parameter of `Test-DevRecipeManifest`. Alternatives considered: `-TomlPath` (exposes the file format, and the internal variable already uses that name) and `-ManifestPath` (easy to confuse with the function parameter when reading the code).

**Resolve the path once, at the top of the script.** Replace the fixed assignment with:
- when `-Manifest` is bound, `$TomlPath` = `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Manifest)`;
- otherwise, the existing `Join-Path $PSScriptRoot "DevRecipe_windows.toml"`.

`GetUnresolvedProviderPathFromPSPath` resolves relative paths against the PowerShell current location without requiring the file to exist. A missing file therefore reaches `Test-DevRecipeManifest` and gets the standard `file not found` diagnostic. `Resolve-Path` was rejected because it fails with a different error before validation runs.

Every existing reader already uses `$TomlPath`, so no reader needs to change. This keeps the change to one assignment plus the parameter.

**Empty or whitespace `-Manifest` is a usage error.** It is rejected with `Stop-Usage` (exit code 2) before the manifest is read, so an empty string cannot silently fall back to the default file.

**Logs stay in the script folder.** `Initialize-DevRecipeLogging` uses `$PSScriptRoot`. Changing it would alter where operators look for logs and is outside this change. The proposal records this assumption.

**Combinable with every mode.** The option is not added to the mode-exclusivity check, because it selects an input rather than an action.

## Risks / Trade-offs

- **Relative paths depend on the current location** → the mode output for validation prints the leaf file name only, so a wrong path is less obvious. Mitigation: the `file not found` diagnostic names the full resolved path, so the operator sees where the script looked.
- **A local variable named `$Manifest` in a function could shadow the parameter** → Mitigation: search for `$Manifest` in `DevRecipe_windows.ps1` before editing, and use a distinct name for any local that matches.
- **The container bundle reads the manifest with the same variable** → Mitigation: covered by the container scenario in the manifest-management delta spec and by the dry-run test for `-Containers`.
- **Acceptance tests copy the default manifest into a temp folder** → Mitigation: add cases that pass `-Manifest` with a path outside the script folder, and keep the existing default-path test unchanged.
