## Why

The current preflight banner displays an obscure technical sentence: "similarity is evidence ordering only, never identity or provenance." Users find this confusing. Before running preflight checks, the system must clearly tell the user what it is doing in plain English: "Scanning requested tools and checking your system for existing traces to prevent installation conflicts." Furthermore, when traces are discovered, they should be explicitly introduced as "Traces found for <application>:" rather than obscure headings.

## What Changes

- Clarify the preflight introductory message on Windows and Unix to state: "Scanning requested tools and checking your system for existing traces to prevent installation conflicts."
- Replace confusing technical wording ("similarity is evidence ordering only...") with clear explanatory text clarifying that name matches are warning indicators, not proof of ownership.
- Format detected evidence blocks with an explicit header: "Traces found for <application>:".

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `preflight-conflict-detection`: Clarifies operator notification and trace display formatting before and during preflight conflict audits.

## Impact

- Runtime scripts: `DevRecipe_windows.ps1` and `DevRecipe_unix.bash`.
- Delta spec for `preflight-conflict-detection`.
- Acceptance test assertions in `tests/acceptance/test_baseline.py` (ensuring compatibility with evidence line checks).
