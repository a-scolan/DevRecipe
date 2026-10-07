#!/usr/bin/env python3
"""Sandboxed contracts for DevRecipe's narrow bootstrapper boundary.

Every provider executable is a local stub. These tests never contact a package
registry, install software, or alter files outside their temporary sandbox.
"""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
BASH = shutil.which("bash")


def find_powershell() -> str | None:
    """Find Windows PowerShell even when the invoking Bash PATH omits it."""
    for candidate in (shutil.which("powershell.exe"), shutil.which("powershell"), shutil.which("pwsh")):
        if candidate:
            return candidate
    system_root = os.environ.get("SystemRoot")
    if system_root:
        candidate = Path(system_root) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
        if candidate.is_file():
            return str(candidate)
    return None


POWERSHELL = find_powershell()


def bash_path(path: Path) -> str:
    """Render a temporary Windows path for the MSYS Bash used in tests."""
    value = str(path)
    if os.name != "nt":
        return value
    drive, tail = os.path.splitdrive(value)
    if drive:
        normalised_tail = tail.replace("\\", "/")
        return f"/{drive[0].lower()}{normalised_tail}"
    return value.replace("\\", "/")


def read_calls(log_path: Path) -> list[tuple[str, list[str]]]:
    """Read command names and space-separated arguments emitted by local stubs."""
    if not log_path.exists():
        return []
    calls: list[tuple[str, list[str]]] = []
    for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
        command, _, arguments = line.partition("\t")
        calls.append((command, arguments.split()))
    return calls


def calls_for(calls: list[tuple[str, list[str]]], command: str) -> list[list[str]]:
    """Return every recorded invocation for one fake executable."""
    return [arguments for actual_command, arguments in calls if actual_command == command]


def write_bash_stub(directory: Path, command: str, body: str = "exit 0") -> None:
    """Create a Bash provider stub that logs each invocation before acting."""
    path = directory / command
    path.write_text(
        "#!/usr/bin/env bash\n"
        "set -eu\n"
        f'printf "{command}\\t%s\\n" "$*" >> "$DEVRECIPE_CALL_LOG"\n'
        f"{body}\n",
        encoding="utf-8",
    )
    path.chmod(0o755)


def write_windows_stub(directory: Path, command: str, body: str = "exit /b 0") -> None:
    """Create a Windows provider stub that logs each invocation before acting."""
    (directory / f"{command}.cmd").write_text(
        "@echo off\n"
        f'>> "%DEVRECIPE_CALL_LOG%" echo {command}\t%*\n'
        f"{body}\n",
        encoding="utf-8",
    )


class RecipeSandbox(unittest.TestCase):
    """Run public recipes from copied files with fake provider executables."""

    maxDiff = None

    def assert_success(self, execution: dict[str, object]) -> None:
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertEqual(0, result.returncode, f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")

    def windows_runtime_helpers(self) -> str:
        """Extract embedded helper definitions for focused helper probes."""
        source = (REPOSITORY_ROOT / "DevRecipe_windows.ps1").read_text(encoding="utf-8")
        start = source.index("$script:DevRecipePreflightThreshold = 90")
        end = source.index("# End private runtime helpers.", start)
        return source[start:end]

    def run_windows(
        self,
        arguments: list[str],
        *,
        manifest_text: str | None = None,
        fixture: dict[str, str] | None = None,
        script_prelude: str | None = None,
        shell_config_files: dict[str, str] | None = None,
    ) -> dict[str, object]:
        self.assertIsNotNone(POWERSHELL, "PowerShell is required for this scenario")
        with tempfile.TemporaryDirectory(prefix="devrecipe-windows-") as temporary_directory:
            sandbox = Path(temporary_directory)
            recipe = sandbox / "recipe"
            fake_bin = sandbox / "fake-bin"
            home = sandbox / "home"
            recipe.mkdir()
            fake_bin.mkdir()
            home.mkdir()
            if script_prelude is None:
                shutil.copy2(REPOSITORY_ROOT / "DevRecipe_windows.ps1", recipe / "DevRecipe_windows.ps1")
            else:
                recipe_source = (REPOSITORY_ROOT / "DevRecipe_windows.ps1").read_text(encoding="utf-8")
                runtime_end = "# End private runtime helpers."
                self.assertIn(runtime_end, recipe_source)
                recipe_source = recipe_source.replace(runtime_end, f"{runtime_end}\n\n{script_prelude}", 1)
                (recipe / "DevRecipe_windows.ps1").write_text(recipe_source, encoding="utf-8")
            shutil.copy2(REPOSITORY_ROOT / "DevRecipe_windows.toml", recipe / "DevRecipe_windows.toml")
            if manifest_text is not None:
                (recipe / "DevRecipe_windows.toml").write_text(manifest_text, encoding="utf-8")

            log_path = sandbox / "provider.log"
            shell_config_root = sandbox / "shell-config"
            user_path_file = sandbox / "user-path.txt"
            autorun_file = sandbox / "autorun.txt"
            initial_user_path = (fixture or {}).get("DEVRECIPE_TEST_INITIAL_USER_PATH")
            if initial_user_path is not None:
                user_path_file.write_text(
                    initial_user_path.replace("%LOCALAPPDATA%", str(home / "AppData" / "Local")),
                    encoding="utf-8",
                )
            initial_autorun = (fixture or {}).get("DEVRECIPE_TEST_INITIAL_AUTORUN")
            if initial_autorun is not None:
                autorun_file.write_text(initial_autorun, encoding="utf-8")
            if shell_config_files is not None:
                for relative_path, file_text in shell_config_files.items():
                    target = shell_config_root / relative_path
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text(file_text, encoding="utf-8")
            write_windows_stub(
                fake_bin,
                "scoop",
                'if /i "%~1"=="export" echo %DEVRECIPE_SCOOP_JSON%\nif /i "%~1"=="install" if not "%DEVRECIPE_SCOOP_INSTALL_STDOUT%"=="" echo %DEVRECIPE_SCOOP_INSTALL_STDOUT%\nexit /b 0',
            )
            write_windows_stub(
                fake_bin,
                "mise",
                'if /i "%~1"=="ls" if /i "%~2"=="--installed" if /i "%~3"=="--json" if not "%DEVRECIPE_MISE_JSON%"=="" echo %DEVRECIPE_MISE_JSON%\nexit /b 0',
            )

            environment = os.environ.copy()
            environment.update(
                {
                    "DEVRECIPE_CALL_LOG": str(log_path),
                    "DEVRECIPE_SCOOP_JSON": '{"apps":[]}',
                    "DEVRECIPE_MISE_JSON": "{}",
                    "DEVRECIPE_TEST_SHELL_CONFIG_ROOT": str(shell_config_root),
                    "DEVRECIPE_TEST_AVAILABLE_SHELLS": "powershell,pwsh,nu,bash,zsh,fish,elvish,xonsh",
                    "DEVRECIPE_TEST_USER_PATH_FILE": str(user_path_file),
                    "DEVRECIPE_TEST_AUTORUN_FILE": str(autorun_file),
                    "USERPROFILE": str(home),
                    "LOCALAPPDATA": str(home / "AppData" / "Local"),
                    "APPDATA": str(home / "AppData" / "Roaming"),
                    "PATH": os.pathsep.join([str(fake_bin), environment.get("PATH", "")]),
                    "PATHEXT": ".COM;.EXE;.BAT;.CMD",
                }
            )
            environment.update(fixture or {})
            result = subprocess.run(
                [str(POWERSHELL), "-NoProfile", "-File", str(recipe / "DevRecipe_windows.ps1"), *arguments],
                cwd=recipe,
                env=environment,
                text=True,
                errors="replace",
                capture_output=True,
                check=False,
            )
            nginx_root = home / ".config" / "devrecipe" / "nginx"
            shell_configs = {
                str(path.relative_to(shell_config_root)): path.read_text(encoding="utf-8")
                for path in shell_config_root.rglob("*")
                if path.is_file()
            }
            logs_dir = recipe / "logs"
            log_files = [path.name for path in logs_dir.glob("devrecipe-windows-*.log")] if logs_dir.is_dir() else []
            return {
                "result": result,
                "calls": read_calls(log_path),
                "log_files": log_files,
                "nginx_config": (nginx_root / "nginx.conf").exists(),
                "nginx_launcher": (nginx_root / "devrecipe-nginx.ps1").exists(),
                "mise_config": (home / ".config" / "mise" / "config.toml").exists(),
                "shell_configs": shell_configs,
                "user_path": user_path_file.read_text(encoding="utf-8") if user_path_file.exists() else None,
                "autorun": autorun_file.read_text(encoding="utf-8") if autorun_file.exists() else None,
                "shims_cmd": (home / "AppData" / "Local" / "DevRecipe" / "shims_prepend.cmd").exists(),
                "state": (home / "AppData" / "Local" / "DevRecipe" / "state" / "state-v1.toml").exists(),
            }


class WindowsBootstrapperContractTests(RecipeSandbox):
    """Windows counterpart for list/status, normal Nginx, and exact removal."""
    def test_public_runtime_messages_do_not_regress_to_french(self) -> None:
        source = (REPOSITORY_ROOT / "DevRecipe_windows.ps1").read_text(encoding="utf-8")
        forbidden = ("Manifeste", "Choisissez", "Suppression refusée", "Aucune mutation", 'lang="fr"')
        for text in forbidden:
            with self.subTest(text=text):
                self.assertNotIn(text, source)


    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_validate_list_and_dry_run_are_non_mutating(self) -> None:
        preflight_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        for arguments in (["-Validate"], ["-List"], ["-DryRun"]):
            with self.subTest(arguments=arguments):
                execution = self.run_windows(
                    arguments,
                    script_prelude=preflight_prelude if arguments == ["-DryRun"] else None,
                )
                self.assert_success(execution)
                if arguments == ["-DryRun"]:
                    self.assertIn(["export"], calls_for(execution["calls"], "scoop"))
                    self.assertFalse(any(args[:1] == ["install"] for args in calls_for(execution["calls"], "scoop")))
                else:
                    self.assertEqual([], execution["calls"])
                self.assertFalse(execution["nginx_config"])
                self.assertFalse(execution["mise_config"])
        listed = self.run_windows(["-List"])
        result = listed["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertIn("nginx", result.stdout)
        self.assertNotIn("opt-in", result.stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_status_and_default_install_include_nginx_without_devrecipe_files(self) -> None:
        preflight_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        status = self.run_windows(
            ["-Status"],
            fixture={
                "DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"git"}]}',
                "DEVRECIPE_MISE_JSON": '{"node":[{"version":"22.0.0","requested_version":"latest","installed":true}]}',
            },
        )
        self.assert_success(status)
        self.assertIn(["export"], calls_for(status["calls"], "scoop"))
        self.assertIn(["ls", "--installed", "--json"], calls_for(status["calls"], "mise"))
        self.assertFalse(any(args[:1] == ["install"] for args in calls_for(status["calls"], "scoop")))

        default = self.run_windows(
            [],
            fixture={"DEVRECIPE_SCOOP_INSTALL_STDOUT": "Updating buckets: commit log"},
            script_prelude=preflight_prelude,
        )
        self.assert_success(default)
        default_calls = default["calls"]
        self.assertIn(["export"], calls_for(default_calls, "scoop"))
        scoop_installs = [args for args in calls_for(default_calls, "scoop") if args[:1] == ["install"]]
        self.assertTrue(scoop_installs)
        export_index = default_calls.index(("scoop", ["export"]))
        install_index = next(index for index, call in enumerate(default_calls) if call[0] == "scoop" and call[1][:1] == ["install"])
        self.assertLess(export_index, install_index)
        default_result = default["result"]
        self.assertIsInstance(default_result, subprocess.CompletedProcess)
        self.assertIn("FINAL INSTALLATION PLAN AFTER PREFLIGHT", default_result.stdout)
        self.assertNotIn("DRY-RUN PLAN (no changes)", default_result.stdout)
        self.assertNotIn("Updating buckets: commit log", default_result.stdout)
        self.assertIn("INSTALLATION SUMMARY", default_result.stdout)
        self.assertIn("Full execution log: logs/devrecipe-windows-", default_result.stdout)
        self.assertRegex(default_result.stdout, r"\[\d+/\d+\s+\(\d+%\)\]")
        self.assertTrue(len(default["log_files"]) >= 1)
        self.assertTrue(any("nginx" in args for args in scoop_installs))
        self.assertFalse(default["nginx_config"])
        self.assertFalse(default["nginx_launcher"])
        self.assertFalse(default["mise_config"])
        self.assertFalse(default["state"])
        self.assertIn(["reshim"], calls_for(default_calls, "mise"))
        self.assertIn("mise activate pwsh --shims", default["shell_configs"]["WindowsPowerShell\\Microsoft.PowerShell_profile.ps1"])
        self.assertEqual([], calls_for(default_calls, "systemctl"))

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_installation_streamlines_stdout_and_creates_workspace_log(self) -> None:
        preflight_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        execution = self.run_windows(
            [],
            fixture={
                "DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"git"}]}',
                "DEVRECIPE_SCOOP_INSTALL_STDOUT": "Creating shim for 'nginx'... & echo Linking ~\\scoop\\apps\\nginx... Done & echo Installing 'nginx'... & echo Checking hash ... OK & echo Notes & echo Some manual notes & echo ----- & echo nginx was installed successfully!",
            },
            script_prelude=preflight_prelude,
        )
        self.assert_success(execution)
        result = execution["result"]
        self.assertIn("INSTALLATION SUMMARY", result.stdout)
        self.assertIn("Installed:", result.stdout)
        self.assertIn("Current / Unchanged:", result.stdout)
        self.assertNotIn("Creating shim", result.stdout)
        self.assertNotIn("Linking ~\\scoop", result.stdout)
        self.assertNotIn("Some manual notes", result.stdout)
        self.assertTrue(len(execution["log_files"]) == 1)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_default_mise_shims_cover_available_compatible_shells(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        dry_run = self.run_windows(["-DryRun"], script_prelude=script_prelude)
        self.assert_success(dry_run)
        dry_run_result = dry_run["result"]
        self.assertIsInstance(dry_run_result, subprocess.CompletedProcess)
        self.assertIn("Mise: mise reshim.", dry_run_result.stdout)
        self.assertIn("cmd.exe and new processes", dry_run_result.stdout)
        self.assertIn("Command Processor: configure AutoRun in HKCU", dry_run_result.stdout)
        self.assertIn("Shell startup files: add Mise shims activation commands", dry_run_result.stdout)
        self.assertEqual({}, dry_run["shell_configs"])

        install = self.run_windows(
            [],
            fixture={"DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"mise"}]}'},
            script_prelude=script_prelude,
        )
        self.assert_success(install)
        install_result = install["result"]
        self.assertIsInstance(install_result, subprocess.CompletedProcess)
        self.assertIn(["reshim"], calls_for(install["calls"], "mise"))
        self.assertTrue(install["shims_cmd"])
        self.assertIsInstance(install["autorun"], str)
        self.assertIn("shims_prepend.cmd", install["autorun"])
        shell_configs = install["shell_configs"]
        expected_snippets = {
            "WindowsPowerShell\\Microsoft.PowerShell_profile.ps1": "mise activate pwsh --shims",
            "PowerShell\\Microsoft.PowerShell_profile.ps1": "mise activate pwsh --shims",
            "nushell\\env.nu": "mise activate nu --shims",
            "nushell\\config.nu": "use ($nu.default-config-dir | path join mise.nu)",
            ".bash_profile": "mise activate bash --shims",
            ".bashrc": "mise activate bash --shims",
            ".zprofile": "mise activate zsh --shims",
            ".zshrc": "mise activate zsh --shims",
            "fish\\config.fish": "mise activate fish --shims",
            "elvish\\rc.elv": "mise activate elvish --shims",
            ".xonshrc": "mise activate xonsh --shims",
        }
        self.assertEqual(set(expected_snippets), set(shell_configs))
        for path, snippet in expected_snippets.items():
            with self.subTest(path=path):
                self.assertIn(snippet, shell_configs[path])
        self.assertIsInstance(install["user_path"], str)
        self.assertEqual(1, install["user_path"].count("AppData\\Local\\mise\\shims"))

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_mise_shims_user_path_preserves_entries_and_is_idempotent(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        added = self.run_windows(
            [],
            fixture={"DEVRECIPE_TEST_INITIAL_USER_PATH": r"C:\DevTools;D:\Existing"},
            script_prelude=script_prelude,
        )
        self.assert_success(added)
        added_path = added["user_path"]
        self.assertIsInstance(added_path, str)
        self.assertTrue(added_path.split(";", 1)[0].endswith(r"\AppData\Local\mise\shims"))
        self.assertIn(r";C:\DevTools;D:\Existing", added_path)
        self.assertEqual(1, added_path.count(r"\mise\shims"))

        already_present = self.run_windows(
            [],
            fixture={"DEVRECIPE_TEST_INITIAL_USER_PATH": r"%LOCALAPPDATA%\mise\shims;C:\DevTools"},
            script_prelude=script_prelude,
        )
        self.assert_success(already_present)
        already_present_path = already_present["user_path"]
        self.assertIsInstance(already_present_path, str)
        self.assertEqual(1, already_present_path.count(r"\mise\shims"))
        self.assertIn("already first in the user PATH", already_present["result"].stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_default_mise_shims_are_idempotent(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""

        existing_profile = "# DevRecipe: Mise shims activation\n"
        install = self.run_windows(
            [],
            fixture={"DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"mise"}]}'},
            script_prelude=script_prelude,
            shell_config_files={"WindowsPowerShell\\Microsoft.PowerShell_profile.ps1": existing_profile},
        )
        self.assert_success(install)
        install_result = install["result"]
        self.assertIsInstance(install_result, subprocess.CompletedProcess)
        self.assertIn(["reshim"], calls_for(install["calls"], "mise"))
        self.assertIn("Mise shims activation is already present", install_result.stdout)
        self.assertEqual(existing_profile, install["shell_configs"]["WindowsPowerShell\\Microsoft.PowerShell_profile.ps1"])

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_retired_nginx_parameter_is_rejected_without_provider_calls(self) -> None:
        execution = self.run_windows(["-Nginx"])
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertNotEqual(0, result.returncode)
        self.assertEqual([], execution["calls"])

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_preflight_excludes_exact_provider_inventory_without_conflict(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        execution = self.run_windows(
            ["-Preflight", "-DryRun"],
            fixture={"DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"git"}]}'},
            script_prelude=script_prelude,
        )
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertEqual(0, result.returncode)
        self.assertIn("PREFLIGHT CONFLICT EVIDENCE", result.stdout)
        self.assertNotIn("PREFLIGHT CHECK: git", result.stdout)
        self.assertNotIn("query=git", result.stdout)
        self.assertNotIn("git", next(line for line in result.stdout.splitlines() if line.startswith("Scoop: scoop install")))
        self.assertIn(["export"], calls_for(execution["calls"], "scoop"))
        self.assertFalse(any(args[:1] == ["install"] for args in calls_for(execution["calls"], "scoop")))
        self.assertFalse(execution["nginx_config"])

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_preflight_excludes_only_exact_mise_spec_without_conflict(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        execution = self.run_windows(
            ["-Preflight", "-DryRun"],
            fixture={"DEVRECIPE_MISE_JSON": '{"node":[{"version":"22.0.0","requested_version":"latest","installed":true}],"pnpm":[{"version":"11.0.0","requested_version":"latest","installed":true}],"python":[{"version":"3.14.0","requested_version":"latest","installed":true}],"java":[{"version":"21.0.0","requested_version":"latest","installed":true}]}'},
            script_prelude=script_prelude,
        )
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertEqual(0, result.returncode)
        self.assertIn(["ls", "--installed", "--json"], calls_for(execution["calls"], "mise"))
        self.assertNotIn("PREFLIGHT CHECK: node", result.stdout)
        self.assertNotIn("query=node", result.stdout)
        self.assertNotIn("Mise: mise install", result.stdout)
        self.assertIn("provider-managed | provider=Mise | application=node", result.stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_preflight_reports_exact_provider_versions_as_no_action_state(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        manifest = """\
[metadata]
schema_version = 2

[profiles.default]
description = "Provider match fixture"

[packages.default.os.foundation]
git = "2.0.0"

[runtimes.default.mise.web]
node = "22.0.0"
"""
        execution = self.run_windows(
            ["-Preflight", "-DryRun"],
            manifest_text=manifest,
            fixture={
                "DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"git","Version":"2.0.0"}]}',
                "DEVRECIPE_MISE_JSON": '{"node":[{"version":"22.0.0","installed":true}]}',
            },
            script_prelude=script_prelude,
        )
        self.assert_success(execution)
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertIn("provider-managed | provider=Scoop | application=git | declared-version=2.0.0 | installed-version=2.0.0 | version-match=exact | decision=skip-no-action", result.stdout)
        self.assertIn("provider-managed | provider=Mise | application=node | declared-version=22.0.0 | installed-version=22.0.0 | version-match=exact | decision=skip-no-action", result.stdout)
        self.assertNotIn("PREFLIGHT CHECK: git", result.stdout)
        self.assertNotIn("PREFLIGHT CHECK: node", result.stdout)
        self.assertNotIn("Scoop: scoop install", result.stdout)
        self.assertNotIn("Mise: mise install", result.stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_preflight_requires_decision_for_provider_version_mismatch(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        manifest = """\
[metadata]
schema_version = 2

[profiles.default]
description = "Provider mismatch fixture"

[packages.default.os.foundation]
git = "2.0.0"

[runtimes.default.mise.web]
node = "22.0.0"
"""
        execution = self.run_windows(
            ["-Preflight", "-DryRun"],
            manifest_text=manifest,
            fixture={
                "DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"git","Version":"1.0.0"}]}',
                "DEVRECIPE_MISE_JSON": '{"node":[{"version":"21.0.0","installed":true}]}',
            },
            script_prelude=script_prelude,
        )
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertEqual(3, result.returncode)
        self.assertIn("provider-conflict | provider=Scoop | application=git | declared-version=2.0.0 | installed-version=1.0.0 | reason=provider-version-mismatch", result.stdout)
        self.assertIn("provider-conflict | provider=Mise | application=node | declared-version=22.0.0 | installed-version=21.0.0 | reason=provider-version-mismatch", result.stdout)
        self.assertIn("Preflight needs human decisions", result.stderr)
        self.assertFalse(any(args[:1] == ["install"] for args in calls_for(execution["calls"], "scoop")))

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_preflight_streamlines_output_and_tracks_progress(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    if ($Query -eq "curl") {
        return (Write-DevRecipePreflightEvidence -Query $Query -Source "os-installation-record:fixture" -Scope "user" -Location "<fixture>" -Value "curl")
    }
    return $false
}
"""
        manifest = """\
[metadata]
schema_version = 2

[profiles.default]
description = "Streamlined preflight fixture"

[packages.default.os.foundation]
git = "latest"
curl = "latest"
nginx = "latest"
"""
        execution = self.run_windows(
            ["-Preflight", "-DryRun", "-Force"],
            manifest_text=manifest,
            fixture={
                "DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"git"}]}',
            },
            script_prelude=script_prelude,
        )
        self.assert_success(execution)
        result = execution["result"]
        # Conflicted entry must display check header and traces
        self.assertIn("--- PREFLIGHT CHECK: curl ---", result.stdout)
        self.assertIn("Traces found for 'curl':", result.stdout)
        self.assertIn("decision=force (pre-approved via -Force) | application=curl", result.stdout)
        # Clean entry without conflict must be omitted from check headers (only in bilan/summary)
        self.assertNotIn("--- PREFLIGHT CHECK: nginx ---", result.stdout)
        # Provider-managed entry must appear in provider-managed summary
        self.assertIn("provider-managed | provider=Scoop | application=git", result.stdout)
        self.assertNotIn("--- PREFLIGHT CHECK: git ---", result.stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_preflight_uses_generated_prefix_matches_and_target_path(self) -> None:
        with tempfile.TemporaryDirectory(prefix="devrecipe-preflight-matches-") as temporary_directory:
            temporary_path = Path(temporary_directory)
            command_directory = temporary_path / "terminal-bin"
            command_directory.mkdir()
            (command_directory / "gh.cmd").write_text("@echo off\n", encoding="utf-8")
            probe = temporary_path / "matches.ps1"
            probe.write_text(
                f"{self.windows_runtime_helpers()}\n"
                f"$env:PATH = '{command_directory};' + $env:PATH\n"
                "$records = @(\n"
                "    @('yed', 'yEd Graph Editor 3.25.1'),\n"
                "    @('firefox-developer', 'FirefoxDeveloper Edition (x64 fr)'),\n"
                "    @('visual-studio-code', 'VisualStudioCode'),\n"
                "    @('git', 'GitHub CLI')\n"
                ")\n"
                "foreach ($record in $records) {\n"
                "    Start-DevRecipePreflightEvidenceCollection\n"
                "    $found = Write-DevRecipePreflightEvidence -Query $record[0] -Source 'os-installation-record:registry' -Scope 'user' -Location 'HKCU:\\fixture' -Value $record[1]\n"
                "    Write-Output \"$($record[0])=$found\"\n"
                "    Complete-DevRecipePreflightEvidenceCollection\n"
                "}\n"
                "Start-DevRecipePreflightEvidenceCollection\n"
                "$pathFound = Find-DevRecipeWindowsPathEvidence -Query 'gh'\n"
                "Write-Output \"gh=$pathFound\"\n"
                "Complete-DevRecipePreflightEvidenceCollection\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [str(POWERSHELL), "-NoProfile", "-File", str(probe)],
                text=True,
                errors="replace",
                capture_output=True,
                check=False,
            )

        self.assertEqual(0, result.returncode, f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")
        self.assertIn("yed=True", result.stdout)
        self.assertIn("reason=generated separator-flexible prefix match", result.stdout)
        self.assertIn("firefox-developer=True", result.stdout)
        self.assertIn("visual-studio-code=True", result.stdout)
        self.assertIn("git=False", result.stdout)
        self.assertIn("gh=True", result.stdout)
        self.assertIn("query=gh | source=os-path-application | scope=process", result.stdout)
        self.assertIn(f"location={command_directory}\\gh.cmd", result.stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_preflight_decline_excludes_only_detected_entry(self) -> None:
        script_prelude = """\
function Test-DevRecipeInteractiveTerminal { return $true }
function Get-ScoopInventory { return [PSCustomObject]@{ State = "ready"; PackageIds = @() } }
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)

    if ($Query -ne "git") { return $false }
    return (Write-DevRecipePreflightEvidence -Query $Query -Source "os-installation-record:fixture" -Scope "user" -Location "<fixture>" -Value $Query)
}
$script:DevRecipeTestAnswers = @("n")
function Read-Host {
    param([string]$Prompt)

    $Answer = $script:DevRecipeTestAnswers[0]
    $script:DevRecipeTestAnswers = @($script:DevRecipeTestAnswers | Select-Object -Skip 1)
    return $Answer
}
"""
        execution = self.run_windows(
            [],
            script_prelude=script_prelude,
        )
        self.assert_success(execution)
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertIn("decision=decline", result.stdout)
        self.assertIn("decision=decline | application=git", result.stdout)
        install = next(args for args in calls_for(execution["calls"], "scoop") if args[:1] == ["install"])
        self.assertNotIn("git", install)
        self.assertIn("curl", install)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_preflight_summarises_incomplete_filesystem_coverage_once(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)

    $script:DevRecipePreflightFilesystemCache = @(
        [PSCustomObject]@{ Scope = "machine"; Label = "ProgramFiles"; Relative = $null; Name = $null; Incomplete = "scan limit reached" },
        [PSCustomObject]@{ Scope = "machine"; Label = "ProgramFilesX86"; Relative = $null; Name = $null; Incomplete = "root inaccessible or partial scan" },
        [PSCustomObject]@{ Scope = "machine"; Label = "ProgramData"; Relative = $null; Name = $null; Incomplete = "root inaccessible or partial scan" },
        [PSCustomObject]@{ Scope = "user"; Label = "LocalAppData"; Relative = $null; Name = $null; Incomplete = "scan limit reached" },
        [PSCustomObject]@{ Scope = "user"; Label = "AppData"; Relative = $null; Name = $null; Incomplete = "scan limit reached" }
    )
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return Find-DevRecipeWindowsFilesystemEvidence -Query $Query
}
"""
        execution = self.run_windows(["-Preflight", "-DryRun"], script_prelude=script_prelude)
        self.assert_success(execution)
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertIn("PREFLIGHT COVERAGE NOTE", result.stdout)
        self.assertIn("source=os-location-metadata | scopes=machine,user | incomplete-checks=5", result.stdout)
        self.assertIn("no action is required unless matching evidence is shown", result.stdout)
        self.assertEqual(1, result.stdout.count("coverage | source=os-location-metadata"))
        self.assertNotIn("incomplete | query=", result.stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_preflight_accepts_all_yes_and_all_no(self) -> None:
        with tempfile.TemporaryDirectory(prefix="devrecipe-preflight-decisions-") as temporary_directory:
            probe = Path(temporary_directory) / "preflight.ps1"
            probe.write_text(
                f"{self.windows_runtime_helpers()}\n"
                "function Test-DevRecipeInteractiveTerminal { return $true }\n"
                "function Get-ScoopInventory { return [PSCustomObject]@{ State = 'ready'; PackageIds = @() } }\n"
                "function Initialize-DevRecipeWindowsFilesystemCache { param([object[]]$Entries) }\n"
                "function Find-DevRecipeWindowsOsMetadataEvidence { param([string]$Query); return (Write-DevRecipePreflightEvidence -Query $Query -Source 'os-installation-record:fixture' -Scope 'user' -Location '<fixture>' -Value $Query) }\n"
                "$global:DevRecipePreflightPromptCount = 0\n"
                "$script:DevRecipePreflightAnswers = @('A')\n"
                "function Read-Host {\n"
                "    param([string]$Prompt)\n"
                "    [void]($global:DevRecipePreflightPromptCount += 1)\n"
                "    $answer = $script:DevRecipePreflightAnswers[0]\n"
                "    $script:DevRecipePreflightAnswers = @($script:DevRecipePreflightAnswers | Select-Object -Skip 1)\n"
                "    return $answer\n"
                "}\n"
                "$entries = @([PSCustomObject]@{ Type = 'packages'; Provider = 'os'; Name = 'git'; Version = 'latest' }, [PSCustomObject]@{ Type = 'packages'; Provider = 'os'; Name = 'curl'; Version = 'latest' })\n"
                "$force = Invoke-DevRecipePreflight -Entries $entries\n"
                'Write-Output "force_excluded=$($force.ExcludedIds.Count)"\n'
                "$script:DevRecipePreflightExcludedIds = @()\n"
                "$script:DevRecipePreflightAnswers = @('D')\n"
                "$decline = Invoke-DevRecipePreflight -Entries $entries\n"
                'Write-Output "decline_excluded=$($decline.ExcludedIds.Count)"\n'
                'Write-Output "prompt_count=$global:DevRecipePreflightPromptCount"\n',
                encoding="utf-8",
            )
            result = subprocess.run(
                [str(POWERSHELL), "-NoProfile", "-File", str(probe)],
                text=True,
                errors="replace",
                capture_output=True,
                check=False,
            )

        self.assertEqual(0, result.returncode, f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")
        self.assertIn("force_excluded=0", result.stdout)
        self.assertIn("decline_excluded=2", result.stdout)
        self.assertIn("prompt_count=2", result.stdout)
        self.assertEqual(2, result.stdout.count("--- PREFLIGHT CHECK: git ---"))
        self.assertEqual(2, result.stdout.count("--- PREFLIGHT CHECK: curl ---"))
        self.assertEqual(2, result.stdout.count("decision=force-all"))
        self.assertEqual(2, result.stdout.count("decision=decline-all"))
        self.assertIn("decision=force-all | application=git", result.stdout)
        self.assertIn("decision=force-all | application=curl", result.stdout)
        self.assertIn("decision=decline-all | application=git", result.stdout)
        self.assertIn("decision=decline-all | application=curl", result.stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_native_preflight_checklist_uses_terminal_height_for_viewport(self) -> None:
        with tempfile.TemporaryDirectory(prefix="devrecipe-windows-menu-height-") as temporary_directory:
            probe = Path(temporary_directory) / "height.ps1"
            probe.write_text(
                f"{self.windows_runtime_helpers()}\n"
                "$short = Get-DevRecipePreflightViewport -EntryCount 12 -WindowHeight 10\n"
                "$tall = Get-DevRecipePreflightViewport -EntryCount 12 -WindowHeight 16\n"
                "$tooSmall = Get-DevRecipePreflightViewport -EntryCount 12 -WindowHeight 9\n"
                'Write-Output "short=$($short.VisibleRows)"\n'
                'Write-Output "tall=$($tall.VisibleRows)"\n'
                'Write-Output "too_small=$($null -eq $tooSmall)"\n',
                encoding="utf-8",
            )
            result = subprocess.run(
                [str(POWERSHELL), "-NoProfile", "-File", str(probe)],
                text=True,
                errors="replace",
                capture_output=True,
                check=False,
            )

        self.assertEqual(0, result.returncode, f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")
        self.assertIn("short=3", result.stdout)
        self.assertIn("tall=9", result.stdout)
        self.assertIn("too_small=True", result.stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_native_preflight_checklist_forces_only_checked_entries_and_cancel_excludes_all(self) -> None:
        with tempfile.TemporaryDirectory(prefix="devrecipe-preflight-checklist-") as temporary_directory:
            probe = Path(temporary_directory) / "preflight.ps1"
            probe.write_text(
                f"{self.windows_runtime_helpers()}\n"
                "function Test-DevRecipeInteractiveTerminal { return $true }\n"
                "function Get-ScoopInventory { return [PSCustomObject]@{ State = 'ready'; PackageIds = @() } }\n"
                "function Initialize-DevRecipeWindowsFilesystemCache { param([object[]]$Entries) }\n"
                "function Find-DevRecipeWindowsOsMetadataEvidence { param([string]$Query); return (Write-DevRecipePreflightEvidence -Query $Query -Source 'os-installation-record:fixture' -Scope 'user' -Location '<fixture>' -Value $Query) }\n"
                "function Invoke-NativeMultiSelect { param([object[]]$Entries); return [PSCustomObject]@{ Cancelled = $false; Selected = [bool[]]@( $true, $false ) } }\n"
                "$entries = @([PSCustomObject]@{ Type = 'packages'; Provider = 'os'; Name = 'git'; Version = 'latest' }, [PSCustomObject]@{ Type = 'packages'; Provider = 'os'; Name = 'curl'; Version = 'latest' })\n"
                "$selected = Invoke-DevRecipePreflight -Entries $entries\n"
                'Write-Output "selected_excluded=$($selected.ExcludedIds.Count)"\n'
                "$script:DevRecipePreflightExcludedIds = @()\n"
                "function Invoke-NativeMultiSelect { param([object[]]$Entries); return [PSCustomObject]@{ Cancelled = $true; Selected = [bool[]]@( $false, $false ) } }\n"
                "$cancelled = Invoke-DevRecipePreflight -Entries $entries\n"
                'Write-Output "cancelled_excluded=$($cancelled.ExcludedIds.Count)"\n',
                encoding="utf-8",
            )
            result = subprocess.run(
                [str(POWERSHELL), "-NoProfile", "-File", str(probe)],
                text=True,
                errors="replace",
                capture_output=True,
                check=False,
            )

        self.assertEqual(0, result.returncode, f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")
        self.assertIn("selected_excluded=1", result.stdout)
        self.assertIn("cancelled_excluded=2", result.stdout)
        self.assertEqual(1, result.stdout.count("decision=force"))
        self.assertEqual(3, result.stdout.count("decision=decline"))
        self.assertIn("decision=force | application=git", result.stdout)
        self.assertIn("decision=decline | application=git", result.stdout)
        self.assertIn("decision=decline | application=curl", result.stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_review_without_interaction_stops_before_mutation(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        execution = self.run_windows(["-Review"], script_prelude=script_prelude)
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertEqual(3, result.returncode)
        self.assertIn("Review requires an interactive TTY", result.stderr)
        self.assertFalse(any(args[:1] == ["install"] for args in calls_for(execution["calls"], "scoop")))
        self.assertFalse(execution["nginx_config"])

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_review_runs_preflight_before_review_actions(self) -> None:
        script_prelude = """\
function Test-DevRecipeInteractiveTerminal { return $true }
function Get-ScoopInventory { return [PSCustomObject]@{ State = "ready"; PackageIds = @() } }
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)

    if ($Query -ne "git") { return $false }
    return (Write-DevRecipePreflightEvidence -Query $Query -Source "os-installation-record:fixture" -Scope "user" -Location "<fixture>" -Value $Query)
}
$script:DevRecipeTestAnswers = @(\"y\", \"A\")
function Read-Host {
    param([string]$Prompt)

    Write-Host \"test prompt: $Prompt\"
    $Answer = $script:DevRecipeTestAnswers[0]
    $script:DevRecipeTestAnswers = @($script:DevRecipeTestAnswers | Select-Object -Skip 1)
    return $Answer
}
"""
        execution = self.run_windows(
            ["-Review"],
            script_prelude=script_prelude,
        )
        self.assert_success(execution)
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertIn("PREFLIGHT CONFLICT EVIDENCE", result.stdout)
        self.assertIn("query=git", result.stdout)
        preflight_prompt = "test prompt: Force exact declared installation for 'git'? [y/N/A=all yes/D=all no]"
        review_prompt = "test prompt: Approve this exact action? [y/N/A=all remaining]"
        self.assertIn(preflight_prompt, result.stdout)
        self.assertIn("decision=force", result.stdout)
        self.assertIn("decision=force | application=git", result.stdout)
        self.assertIn(review_prompt, result.stdout)
        self.assertLess(result.stdout.index(preflight_prompt), result.stdout.index(review_prompt))
        self.assertEqual(2, result.stdout.count("test prompt:"))
        self.assertIn("approval: all remaining review actions", result.stdout)
        self.assertIn(["export"], calls_for(execution["calls"], "scoop"))
        self.assertIn(["install", "git"], calls_for(execution["calls"], "scoop"))

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_review_uses_individual_package_actions_and_accepts_uppercase_a(self) -> None:
        recipe_source = (REPOSITORY_ROOT / "DevRecipe_windows.ps1").read_text(encoding="utf-8")
        self.assertIn("foreach ($Entry in $OsEntries)", recipe_source)
        self.assertIn('Invoke-Scoop -Arguments @("install", $Entry.Name)', recipe_source)
        self.assertIn("foreach ($Entry in $MiseEntries)", recipe_source)
        self.assertIn('Invoke-Mise -Arguments @("install", $Spec)', recipe_source)
        self.assertIn("foreach ($Package in $Packages)", recipe_source)

        with tempfile.TemporaryDirectory(prefix="devrecipe-review-") as temporary_directory:
            probe = Path(temporary_directory) / "review.ps1"
            probe.write_text(
                "$Review = $true\n"
                f"{self.windows_runtime_helpers()}\n"
                "function Test-DevRecipeInteractiveTerminal { return $true }\n"
                "$global:DevRecipeReviewPromptCount = 0\n"
                '$script:DevRecipeReviewAnswers = @("A")\n'
                "function Read-Host {\n"
                "    param([string]$Prompt)\n"
                "    [void]($global:DevRecipeReviewPromptCount += 1)\n"
                "    $answer = $script:DevRecipeReviewAnswers[0]\n"
                "    $script:DevRecipeReviewAnswers = @($script:DevRecipeReviewAnswers | Select-Object -Skip 1)\n"
                "    return $answer\n"
                "}\n"
                'Confirm-DevRecipeReviewAction -Command "scoop install git" -Privilege "user" -Source "Scoop package git" -Effect "install selected package raw ID"\n'
                'Confirm-DevRecipeReviewAction -Command "scoop install curl" -Privilege "user" -Source "Scoop package curl" -Effect "install selected package raw ID"\n'
                "Complete-DevRecipeReview\n"
                'Write-Output "prompt_count=$global:DevRecipeReviewPromptCount"\n',
                encoding="utf-8",
            )
            result = subprocess.run(
                [str(POWERSHELL), "-NoProfile", "-File", str(probe)],
                text=True,
                errors="replace",
                capture_output=True,
                check=False,
            )

        self.assertEqual(0, result.returncode, f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")
        self.assertIn("prompt_count=1", result.stdout)
        self.assertIn("approved: 2", result.stdout)
        self.assertIn("completed: 2", result.stdout)

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_uninstall_is_confirmed_and_version_specific(self) -> None:
        fixture = {
            "DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"git"}]}',
            "DEVRECIPE_MISE_JSON": '{"node":[{"version":"22.0.0","requested_version":"latest","installed":true}]}',
        }
        plan = self.run_windows(["-Uninstall", "git,node"], fixture=fixture)
        self.assert_success(plan)
        self.assertEqual([], plan["calls"])

        confirmed = self.run_windows(["-Uninstall", "git,node", "-Yes"], fixture=fixture)
        self.assert_success(confirmed)
        self.assertIn(["uninstall", "node@latest"], calls_for(confirmed["calls"], "mise"))
        self.assertIn(["uninstall", "git"], calls_for(confirmed["calls"], "scoop"))
        self.assertFalse(any("-p" in args for args in calls_for(confirmed["calls"], "scoop")))

        blocked = self.run_windows(
            ["-Uninstall", "git,node", "-Yes"],
            fixture={"DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"git"}]}'},
        )
        blocked_result = blocked["result"]
        self.assertIsInstance(blocked_result, subprocess.CompletedProcess)
        self.assertNotEqual(0, blocked_result.returncode)
        self.assertFalse(any(args[:1] == ["uninstall"] for args in calls_for(blocked["calls"], "scoop")))

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_container_dry_run_is_integrated_after_validation(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
}
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query)
    return $false
}
"""
        execution = self.run_windows(["-Containers", "-DryRun"], script_prelude=script_prelude)
        self.assert_success(execution)
        result = execution["result"]
        self.assertIsInstance(result, subprocess.CompletedProcess)
        self.assertIn("scoop install podman podman-desktop docker-compose", result.stdout)
        self.assertIn("CONTAINER DRY-RUN PLAN (no changes)", result.stdout)
        self.assertIn(["export"], calls_for(execution["calls"], "scoop"))
        self.assertFalse(any(args[:1] == ["install"] for args in calls_for(execution["calls"], "scoop")))

    @unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
    def test_windows_conflict_safe_global_runtime_activation(self) -> None:
        script_prelude = """\
function Initialize-DevRecipeWindowsFilesystemCache { param([object[]]$Entries) }
function Find-DevRecipeWindowsOsMetadataEvidence { param([string]$Query); return $false }
function Find-DevRecipeWindowsRegistryEvidence { param([string]$Query); return $false }
function Find-DevRecipeWindowsAppPathEvidence { param([string]$Query); return $false }
"""
        manifest_clean = """[metadata]
schema_version = 2
[profiles.default]
description = "Clean runtime test"
[runtimes.default.mise.test]
dummyruntime = "1.0.0"
[tools.default.mise.testtools]
dummytool = "2.0.0"
"""
        # 1. Clean machine: default runtime gets activated via 'mise use -g', tools do not
        execution = self.run_windows(
            [],
            manifest_text=manifest_clean,
            fixture={
                "DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"mise"}]}',
                "DEVRECIPE_MISE_JSON": '{"dummyruntime":[],"dummytool":[]}',
            },
            script_prelude=script_prelude,
        )
        self.assert_success(execution)
        mise_calls = calls_for(execution["calls"], "mise")
        self.assertIn(["use", "-g", "dummyruntime@1.0.0"], mise_calls)
        self.assertFalse(any(call[:2] == ["use", "-g"] and "dummytool" in call[2] for call in mise_calls))
        self.assertIn("Activating runtime globally: dummyruntime@1.0.0", execution["result"].stdout)

        # 2. Existing installation detected: global activation is skipped
        script_prelude_conflict = script_prelude + """
function Test-DevRecipeExistingRuntimeInstallation { param([string]$RuntimeName); return $true }
"""
        execution_conflict = self.run_windows(
            [],
            manifest_text=manifest_clean,
            fixture={
                "DEVRECIPE_SCOOP_JSON": '{"apps":[{"Name":"mise"}]}',
                "DEVRECIPE_MISE_JSON": '{"dummyruntime":[],"dummytool":[]}',
            },
            script_prelude=script_prelude_conflict,
        )
        self.assert_success(execution_conflict)
        mise_calls_conflict = calls_for(execution_conflict["calls"], "mise")
        self.assertNotIn(["use", "-g", "dummyruntime@1.0.0"], mise_calls_conflict)
        self.assertIn("Global activation skipped for 'dummyruntime': existing installation or configuration detected.", execution_conflict["result"].stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
