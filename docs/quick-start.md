# Start and customise DevRecipe

> **Documentation type:** tutorial. Use this page to make a safe first change and provision one supported workstation.

DevRecipe starts from a reviewed platform manifest. You will inspect the defaults, add one optional profile, validate the change, inspect the plan, then install it.

The shipped manifest is a baseline. Customise the TOML for your tools, profiles, and versions, then configure applications after installation.

## Choose your platform file

Use exactly one manifest:

| Host | Manifest | Recipe |
| --- | --- | --- |
| Windows | `DevRecipe_windows.toml` | `./DevRecipe_windows.ps1` |
| macOS | `DevRecipe_macos.toml` | `bash ./DevRecipe_unix.bash` |
| Ubuntu/Debian | `DevRecipe_linux.toml` | `bash ./DevRecipe_unix.bash` |

`DevRecipe_unix.bash` detects macOS or Linux and selects the matching manifest. The examples below use Windows. Replace the command with the Unix form from the table when needed.

## Inspect the shipped baseline

Open your platform TOML file and find the `[packages.default.*]`, `[runtimes.default.mise.*]`, and `[tools.default.mise.*]` sections. The `default` profile always runs. Optional profiles are `ai_agents` and `cloud`.

Validate and list the file before changing it:

```text
./DevRecipe_windows.ps1 -Validate
./DevRecipe_windows.ps1 -List
```

Validation reads TOML only. List prints selected declarations without calling a provider.

## Add one optional profile

First inspect the plan without changing the machine:

```text
./DevRecipe_windows.ps1 -Profile cloud -DryRun
```

Every installation plan, including dry-run, runs a read-only preflight audit automatically. It checks provider inventories and local OS installation evidence for software that may conflict with selected entries. If it reports a conflict in an interactive terminal, choose whether to force or decline that one declared entry; declining it leaves other selected entries in the plan. The [preflight and review reference](preflight-and-review.md) defines audit sources, controls, exit codes, and non-interactive behaviour.

## Make a manifest change

Add a raw provider ID under the platform-appropriate section. For example, to add a Windows Scoop package to the optional cloud profile:

```toml
[packages.cloud.os.utilities]
terraform = "latest"
```

Use the provider's exact ID, not an executable name. Keep optional software in `ai_agents` or `cloud`; put only daily baseline software in `default`. Quote keys containing punctuation:

```toml
[tools.ai_agents.mise.coding_agents]
"npm:@github/copilot" = "latest"
```

For provider choices and existing IDs, see the [package matrix](package-matrix.md).

For package search, provider configuration, Mise activation, updates, or provider-specific recovery, follow the official links in [provider documentation](package-matrix.md#provider-documentation).

## Validate, inspect, then install

After every manifest change:

```text
./DevRecipe_windows.ps1 -Validate
./DevRecipe_windows.ps1 -Profile cloud -DryRun
./DevRecipe_windows.ps1 -Profile cloud
```

The final command may bootstrap its declared provider and installs only entries still present after preflight. Add `-Review` when every host write needs an individual interactive checkpoint; its exact behaviour is documented in the [preflight and review reference](preflight-and-review.md).

## Check the result

```text
./DevRecipe_windows.ps1 -Profile cloud -Status
```

Status reports exact IDs known by their declared provider. It does not prove DevRecipe owns those installations. See [manage a DevRecipe manifest](user-guide.md) for normal package declarations, containers, removal, and recovery.
