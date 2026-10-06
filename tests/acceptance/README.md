# Run local acceptance checks

> Documentation type: how-to guide. Use these commands to validate DevRecipe without calling real package providers.

## Prerequisites

- Python 3.11 or later for `tomllib`
- Windows PowerShell 5.1 or later for recipe scenarios

If Mise resolves your Python command, use the installed Python executable directly.
This avoids automatic tool installation by the shim before the tests start.

## Run the fast developer gate

From the repository root:

```text
python tests/acceptance/developer_gate.py
```

This validates all shipped manifests, local Markdown links, available PowerShell syntax, and executes the fast in-memory unit tests in `tests/unit/`. It completes in under one second and does not run recipe subprocesses.

## Run the full local gate

```text
python tests/acceptance/quality_gate.py
```

This runs the fast gate, then the sandboxed acceptance suite in parallel. It has no network, package-manager, provider-account, or administrator requirement.

## Run the sandboxed suite in parallel

```text
python tests/acceptance/parallel_test_runner.py
```

The runner discovers local `test_*.py` modules and uses up to four worker processes, limited by available CPUs. Each case has its own temporary sandbox. Use `--jobs 1` for serial debugging or choose another limit, such as `--jobs 2`.

The suite copies recipes and manifests into temporary directories, places fake providers first on the child process `PATH`, and inspects their logged arguments. It covers Windows recipe execution, validation, manifest-only list, provider status, version-aware Windows provider matches, dry run, raw-ID forwarding without DevRecipe-generated application files, exact-ID removal, container boundaries, bounded preflight evidence, and non-interactive review rejection.

A passing suite proves fixture command contracts only. It does not prove that a real host installed a package, that a provider inventory establishes ownership, or that a provider can roll back an installation. Read the [baseline test explanation](../../docs/baseline-acceptance-test.md) for details.

## Test native Windows Node shims

The native tests are optional. They do not run Scoop updates or change existing Mise configuration, installations, or shims.
Provide absolute paths to a fixed Mise executable and an underlying Node executable, not the active Node shim.
Each Mise release must include its matching `mise-shim.exe` in the same directory.
Run these checks separately from the parallel sandbox suite.
Its workers can delay shim startup beyond the five-second IPC deadline.

```powershell
$env:DEVRECIPE_NATIVE_MISE_FIXED = 'C:\test-providers\fixed\bin\mise.exe'
$env:DEVRECIPE_NATIVE_NODE = 'C:\test-providers\node\node.exe'
$env:DEVRECIPE_NATIVE_MISE_AFFECTED = 'C:\test-providers\affected\bin\mise.exe'
python -m unittest discover -s tests\acceptance -p test_native_windows_ipc.py -v
```

The fixed release must be Mise 2026.10.1 or later.
The optional affected release is Mise 2026.9.3, before the fix for [jdx/mise#13901](https://github.com/jdx/mise/issues/13901).
The tests copy Node into temporary installations and build native executable shims with isolated configuration, data, and caches.
They check message exchange, distinct failures, temporary file and process cleanup, and preservation of an unrelated Node process.
They compare each generated shim with its release binary and test repair of an old shim through a forced rebuild.
They also check that the result distinguishes the installed version from the active version without rewriting configuration.
