# User-space and enterprise governance

> Documentation type: explanation. This page defines the privilege boundary. It is not a compliance certification.

Start with [DevRecipe](../README.md) for the product scope. This page explains privilege and approval boundaries.

## Precise meaning of user-space

User-space first means that DevRecipe prefers package managers, runtime configuration, shims, caches, and application data owned by the signed-in user. It avoids system-wide installation and permanent administrator sessions where possible.

For the standard Windows developer setup, Scoop and Mise operate in the user profile. The base `DevRecipe_windows.ps1` route does not request UAC and does not run the optional integrated container mode.

User-space does not mean that every platform operation is privilege-free. DevRecipe does not bypass UAC, endpoint protection, application allowlists, proxy controls, code-signing policy, or change control.

## Privilege boundary by operation

| Operation | Normal privilege expectation | Why it is separated |
| --- | --- | --- |
| Windows base recipe: Scoop packages and Mise runtimes | No administrator rights after the organization permits or provisions Scoop | Installation and configuration stay in the user profile |
| Windows Podman, WSL 2, or Hyper-V | Administrator approval after the user explicitly runs `DevRecipe_windows.ps1 -Containers` | Windows virtualization features are system changes |
| Mise runtime installation | No administrator rights after prerequisites are available | Mise stores configuration and runtime shims in the user profile |

## Governance controls

DevRecipe supports review. It does not evade governance:

- Least privilege is the default. Windows containers use a separate opt-in mode with a visible UAC boundary.
- Manifests declare package IDs and runtime versions. Recipes disclose provider bootstraps and privilege exceptions.
- `-Review` requires a real terminal and approval for each planned host write.
- `-Preflight` reports bounded local evidence. It is not an ownership record or a compliance inventory.
- Provider sources, package IDs, runtime versions, and privileged exceptions remain review points.
- UAC cancellation, EDR, AppLocker, WDAC, MDM, proxy rules, and package allowlists remain authoritative.

The platform or security team can approve the manifest, provider sources, runtime versions, and privileged exceptions.

## Responsibilities outside DevRecipe

DevRecipe cannot make a workstation compliant on its own. The organization must decide and enforce:

- approved Scoop buckets and vendor signing keys;
- proxy, TLS inspection, certificate, endpoint protection, and code-signing requirements;
- whether IT provisions package managers or users can bootstrap them;
- required versions, vulnerability scanning, software inventory, and patching cadence; and
- approval for WSL 2, Hyper-V, and other system operations.

If policy disallows a provider, configure DevRecipe to use an approved alternative or provision the provider centrally. Do not use DevRecipe to work around the policy.

## Team model

1. The platform or security team approves providers and sources.
2. The development team reviews manifest changes through source control.
3. Developers run the user-space path where the provider supports it.
4. System-level exceptions remain explicit and optional.

See the [user guide](user-guide.md) to choose the correct package type, and the [installation guide](installation.md) for platform-specific privilege requirements.
