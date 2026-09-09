# Baseline acceptance test

> Documentation type: explanation. This page states what the sandboxed suite proves and what it does not prove.

`tests/acceptance/test_baseline.py` runs the public Windows, macOS, and Linux entry points in temporary directories. Fake provider commands record arguments. The suite does not install, remove, or query real packages.

## Test shape

```mermaid
flowchart LR
    M[Copied manifest and recipe] --> R[Recipe in temporary HOME]
    F[Fake providers] --> R
    R --> L[Recorded provider calls]
    L --> A[Assertions]
```

The Unix fixture copies the standalone `DevRecipe_unix.bash` recipe and its selected manifest, then uses a test-only platform override. The Windows fixture copies the PowerShell recipe and manifest. Provider stubs replace Scoop, Homebrew, APT, Flatpak, Mise, and `sudo` where applicable.

## Covered contract

| Area | Assertions |
| --- | --- |
| Manifest and public recipes | Valid manifests complete without provider calls. The standalone Unix recipe supports both Unix manifests. |
| List and dry run | List is manifest-only. Dry run names provider and bootstrap boundaries without side effects. |
| Status and provider matches | Uses selected-provider inventories, reports version matches where supported, and does not use `PATH` or cross-provider aliases. |
| Installation | Forwards custom and default raw IDs. It does not create a global Mise config or DevRecipe state record. |
| Uninstall | Prints a plan first, requires confirmation, preflights every requested entry, uses version-specific Mise removal, and rejects broad cleanup arguments. |
| Provider safety | Covers conservative APT, Flatpak, Scoop, Homebrew formula and cask, and Mise removal commands. It verifies Mise removal before Homebrew `mise` removal. |
| Containers | Validates before the integrated bundle, displays side-effect-free plans on all hosts, and checks exact APT/Homebrew/Podman calls in the Unix sandbox. |
| Preflight and review | Reports provider-managed state and conflict evidence without mutation, and rejects review before mutation without an interactive terminal. |

Run the suite with the [acceptance-checks how-to](../tests/acceptance/README.md).

## Limits

A green result proves the command contract against controlled stubs. It does not prove package availability, provider authentication, network access, enterprise policy, installation success, application behavior, or provider ownership. It does not provide rollback. Provider presence is status evidence only.
