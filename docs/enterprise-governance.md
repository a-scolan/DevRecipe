# User-space and enterprise cyber governance

> **Documentation type:** explanation. This page defines the privilege boundary of DevRecipe and explains why its design can fit enterprise cyber governance. It is not a compliance certification.

For the product overview and adoption path, start with [DevRecipe](../README.md). This page explains the specific governance boundaries and organisational responsibilities behind that overview.

## Precise meaning of user-space

**User-space first** means DevRecipe prefers package managers, runtime configuration, shims, caches, and application data owned by the signed-in user. It avoids a system-wide installer or a permanent administrator session where possible.

For the standard Windows developer setup, Scoop and Mise operate in the user profile. The base `DevRecipe_windows.ps1` route does not request UAC and does not run the optional integrated container mode.

User-space does **not** mean that every operation on every platform is privilege-free. It does not bypass UAC, endpoint protection, application allowlists, proxy controls, code-signing policy, or enterprise change control.

## Privilege boundary by operation

| Operation | Normal privilege expectation | Why it is separated |
| --- | --- | --- |
| Windows base recipe: Scoop packages and Mise runtimes | No administrator rights after the organisation permits or provisions Scoop | Installs and configuration are scoped to the user profile |
| Windows Podman, WSL 2, or Hyper-V | Administrator approval only after the user explicitly runs `DevRecipe_windows.ps1 -Containers` | Windows virtualisation features are system changes |
| macOS packages after Homebrew is provisioned | Normally the logged-in user | Homebrew package ownership and bootstrap policy remain organisation-specific |
| macOS Homebrew bootstrap or developer prerequisites | May require organisation-approved administrator action | Managed Macs can restrict developer tools, installation locations, or certificates |
| Linux APT packages and the current Linux recipe | `sudo` required | APT changes operating-system packages; this is intentionally not presented as a user-space route |
| Linux Flatpak configuration in the current recipe | Depends on the enterprise Flatpak policy and remote scope | The organisation may require an approved remote or a centrally managed installation |
| Mise runtime installation | No administrator rights after its prerequisites are available | Mise stores configuration and runtime shims in the user profile |
| Vendor repository bootstrap, such as Claude Desktop on Linux | `sudo` required | Adding a system package source is a governed infrastructure change |

## Why this supports enterprise governance

DevRecipe is designed to be **governance-friendly**, not to evade governance:

- **Least privilege by default:** privileged operations are not hidden in the normal Windows recipe. Containers use a separate opt-in mode with a visible UAC boundary.
- **Reviewable intent:** manifests declare package identifiers and runtime versions; reviewed recipes and supporting documentation disclose bootstrap sources and exceptions instead of a private personal checklist.
- **Reviewable change path:** manifests make provider choices explicit, recipes validate their structural contract, and final summaries list requested provider actions without guessing executable ownership or claiming ownership.
- **Human approval option:** `-Review` / `--review` requires a real terminal and explicit approval for each planned host write; unattended execution cannot silently accept a checkpoint.
- **Conflict evidence boundary:** `-Preflight` / `--preflight` is read-only bounded local evidence, not an ownership or compliance inventory. Its incomplete source list must not be treated as an absence assertion.
- **Controlled sources:** the chosen Scoop buckets, Homebrew casks/formulas, APT repositories, Flatpak remotes, and Mise tools are explicit review points.
- **No privilege bypass:** cancelling UAC skips the optional container setup. A block from EDR, AppLocker, WDAC, MDM, a proxy, or a package allowlist remains authoritative.

This gives a cyber or platform team concrete items to approve: the manifest, permitted package sources, required runtime versions, and the small set of privileged exceptions.

## What the organisation still owns

DevRecipe cannot make a workstation compliant on its own. The organisation must decide and enforce:

- approved Scoop buckets, Homebrew taps/casks, APT repositories, Flatpak remotes, and vendor signing keys;
- proxy, TLS-inspection, certificate, endpoint-protection, and code-signing requirements;
- whether package managers are pre-provisioned by IT or may bootstrap themselves;
- required versions, vulnerability scanning, software inventory, and patching cadence;
- who may approve WSL 2, Hyper-V, APT repository changes, and other system-level operations.

If policy disallows a provider, configure DevRecipe to use an approved alternative or provision the provider centrally. Do not use DevRecipe to work around the policy.

## Practical team model

1. The platform or security team approves the permitted providers and sources.
2. The development team reviews manifest changes through normal source-control review.
3. Individual developers run the user-space path without recurring administrator access where the approved provider supports it.
4. System-level exceptions remain explicit, optional, and auditable.

See the [user guide](user-guide.md) to choose the correct package type, and the [installation guide](installation.md) for platform-specific privilege requirements.
