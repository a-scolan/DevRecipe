# Windows Podman environment and machine provider policy

> Documentation type: explanation. This page explains Windows Podman provider selection. See [Install DevRecipe](installation.md#install-containers-separately) for commands.

Windows runs Podman containers in a Linux virtual machine. The provider choice controls that virtual machine. It does not change the Podman CLI or image format.

## Default policy

For a new Podman environment, `DevRecipe_windows.ps1 -Containers` uses this order:

1. Preserve an existing Podman machine.
2. Preserve a WSL 2 distribution where `podman` resolves.
3. Use ready WSL 2.
4. Use ready Hyper-V when WSL 2 is not ready.
5. Enable an available provider when neither is ready. A Windows restart can be required.
6. Prefer WSL 2 when both providers are ready.

Use `-ContainerProvider WSL` or `-ContainerProvider HyperV` to select a provider for a new environment. The option never rewrites an existing machine or distribution.

| Host state | Automatic selection | Reason |
| --- | --- | --- |
| Existing Podman machine | Keep it | Avoids destructive migration and preserves images, volumes, and connections |
| WSL 2 distribution with a working `podman` command | Keep it | Avoids overwriting an existing Ubuntu or other WSL-based Podman environment |
| WSL 2 ready, Hyper-V unavailable or disabled | WSL 2 | Podman's Windows default |
| Hyper-V ready, WSL 2 disabled | Hyper-V | Reuses an enabled provider and avoids an unnecessary WSL change |
| Both ready | WSL 2 | Stable project default and Podman's Windows default |
| Neither ready, WSL 2 feature components available | Enable WSL 2 | Broad compatibility across supported Windows editions |
| Neither ready, WSL 2 unavailable and Hyper-V available | Enable Hyper-V | Uses the available provider |
| Neither provider available | Stop | The helper cannot select a provider safely |

## Why WSL 2 is the default

WSL 2 is Podman's documented default Windows provider. It fits a developer's Linux command-line workflow and wins the automatic choice when both providers are ready.

Hyper-V remains available when it is the approved virtualization path, WSL is blocked, or the host is configured for Hyper-V workloads. Choosing another provider for an existing machine is an intentional migration. DevRecipe does not perform that migration.

## Readiness signals

| Provider | Ready when | Not selected automatically when |
| --- | --- | --- |
| WSL 2 | `Microsoft-Windows-Subsystem-Linux` and `VirtualMachinePlatform` are enabled | An existing Podman/WSL environment is preserved, or WSL features are unavailable while Hyper-V is available |
| Hyper-V | `Microsoft-Hyper-V-All` is enabled and supported by the Windows edition | WSL 2 is also ready, because WSL 2 wins the default tie-breaker |

Both routes need hardware virtualization. Podman Desktop documents at least 6 GB of RAM for a Windows Podman machine. A virtual machine also needs nested virtualization enabled by its host.

## Companion tools in the optional Windows bundle

The integrated container mode reads `[containers.default.os.*]` in `DevRecipe_windows.toml` only after feature setup succeeds without a Windows restart. The current bundle installs:

- `podman` and `podman-desktop`
- `docker-compose`, which Podman discovers as the external provider for `podman compose`

Installing `docker-compose` does not install Docker Desktop. Podman uses it as the Compose provider, so `podman compose` is available after the bundle is installed.

The Kubernetes client belongs to `[tools.cloud.mise.infrastructure]`, not the container bundle. Select `cloud` with `DevRecipe_windows.ps1 -Profile cloud` when `kubectl` is required. Installing it does not create, start, or register a Kubernetes cluster. DevRecipe does not enable Kind, Minikube, or another local Kubernetes provider.

## Optional `docker` command compatibility

Use Podman commands by default. If an existing script genuinely requires `docker`, run `DevRecipe_windows.ps1 -Containers -EnableDockerAlias`. After the manifest-declared tools are installed, it writes a PowerShell-profile function that forwards `docker ...` to `podman ...`.

This compatibility layer is deliberately opt-in. The container mode first checks whether `docker` already resolves. If it does, it leaves that command untouched. It also does not add the alias when it preserves an existing Podman machine or WSL 2 Podman environment. Open a new PowerShell session after the profile is updated. `docker compose ...` then reaches `podman compose ...` and uses the same Compose provider.

## Boundaries

- The container mode is opt-in. It checks existing Podman machines and WSL 2 distributions before UAC. A match stops setup without changing Windows features, installing packages, or adding an alias.
- It requests UAC only when no preserved environment is found. Cancelling UAC skips container setup without changing Windows features or installing packages.
- The elevated process enables the selected Windows features and, for the WSL route, creates a missing user `.wslconfig` without replacing an existing one. After setup succeeds without a restart, the normal-user process installs `[containers.default.os.*]` with Scoop. If Windows needs a restart, no container package is installed until you restart Windows and run `DevRecipe_windows.ps1 -Containers` again.
- Podman Desktop onboarding and CLI initialisation are alternative ways to create **one** machine. Do not use both for the same initial setup.

## References

- [Podman machine providers](https://docs.podman.io/en/latest/markdown/podman-machine.1.html)
- [Podman Compose](https://docs.podman.io/en/latest/markdown/podman-compose.1.html)
- [Podman Desktop for Windows](https://podman-desktop.io/docs/installation/windows-install)
