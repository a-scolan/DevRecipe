# Run local acceptance checks

> **Documentation type:** how-to guide. Use these commands to validate DevRecipe without calling real package providers.

## Prerequisites

- Python 3.11 or later for `tomllib`;
- Bash for macOS/Linux recipe scenarios; and
- Windows PowerShell for Windows scenarios.

Platform-specific tests are skipped when their interpreter is unavailable. On Windows, the gate also checks the standard Windows PowerShell path when Bash has omitted it from `PATH`.

## Run the fast developer gate

From the repository root:

```text
python tests/acceptance/developer_gate.py
```

This validates all shipped manifests, local Markdown links, Bash syntax, and available PowerShell syntax. It does not run recipe subprocesses.

## Run the full local gate

```text
python tests/acceptance/quality_gate.py
```

This runs the fast gate, then the sandboxed acceptance suite in parallel. It has no network, package-manager, provider-account, or administrator requirement.

## Run the sandboxed suite in parallel

```text
python tests/acceptance/parallel_test_runner.py
```

The runner discovers local `test_*.py` modules and uses up to four worker processes, limited by available CPUs. Each case retains its own temporary sandbox. Use `--jobs 1` for serial debugging or choose a different limit, for example `--jobs 2`.

The suite copies recipes and manifests into temporary directories, places fake providers first on the child process `PATH`, and inspects their logged arguments. It covers standalone Unix execution, validation, manifest-only list, provider-native status, dry run, raw-ID forwarding for default entries without DevRecipe-generated application files, exact-ID removal, container boundaries, selected-provider preflight evidence (including redacted bounded Unix metadata), and non-interactive review rejection.

A passing suite proves fixture command contracts only. It does not prove that a real host installed a package, that a provider inventory establishes ownership, or that a provider can roll back an installation. Read the [baseline test explanation](../../docs/baseline-acceptance-test.md) for details.
