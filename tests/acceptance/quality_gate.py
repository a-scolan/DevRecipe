#!/usr/bin/env python3
"""Run the local DevRecipe quality gate without real provider mutations."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import sys

from manifest_contract import REPOSITORY_ROOT, validate_repository_manifests
from markdown_links import validate_markdown_links


def print_errors(title: str, errors: list[str]) -> bool:
    """Print one validation section and report whether it failed."""
    print(f"==> {title}")
    if not errors:
        print("OK")
        return False
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    return True


def run_command(title: str, command: list[str]) -> bool:
    """Run one local check and return True when it fails."""
    print(f"==> {title}")
    environment = os.environ.copy()
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run(command, cwd=REPOSITORY_ROOT, env=environment, check=False)
    if result.returncode == 0:
        print("OK")
        return False
    return True


def check_bash_syntax() -> bool:
    """Parse all Bash recipes when Bash is available on the current host."""
    bash = shutil.which("bash")
    recipes = sorted(path.name for path in REPOSITORY_ROOT.glob("DevRecipe_*.bash"))
    if bash is None:
        print("==> Bash syntax\nSKIPPED: Bash unavailable.")
        return False
    return run_command("Bash syntax", [bash, "-n", *recipes])


def find_powershell() -> str | None:
    """Find native Windows PowerShell even when Bash omitted it from PATH."""
    for candidate in (shutil.which("powershell.exe"), shutil.which("powershell"), shutil.which("pwsh")):
        if candidate is not None:
            return candidate
    for variable in ("SystemRoot", "WINDIR"):
        root = os.environ.get(variable)
        if root is None:
            continue
        candidate = Path(root) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
        if candidate.is_file():
            return str(candidate)
    return None


def check_powershell_syntax() -> bool:
    """Parse all PowerShell recipes when a PowerShell interpreter is available."""
    powershell = find_powershell()
    if powershell is None:
        print("==> PowerShell syntax\nSKIPPED: PowerShell unavailable.")
        return False

    parser_command = """
$failures = @()
Get-ChildItem -LiteralPath . -Filter 'DevRecipe_*.ps1' -File | ForEach-Object {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    $failures += $errors
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
"""
    return run_command("PowerShell syntax", [powershell, "-NoProfile", "-Command", parser_command])


def run_unit_tests() -> bool:
    """Run fast unit tests targeting pure parsing and algorithmic helpers."""
    print("==> Fast unit tests")
    unit_dir = REPOSITORY_ROOT / "tests" / "unit"
    if not unit_dir.is_dir():
        print("SKIPPED: unit tests directory not found.")
        return False
    environment = os.environ.copy()
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    environment["PYTHONPATH"] = str(REPOSITORY_ROOT)
    result = subprocess.run(
        [sys.executable, "-m", "unittest", "discover", "-s", "tests/unit"],
        cwd=REPOSITORY_ROOT,
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0:
        print("OK")
        return False
    print(result.stdout, file=sys.stderr)
    print(result.stderr, file=sys.stderr)
    return True


def run_developer_checks() -> bool:
    """Run fast deterministic checks suitable for each developer edit."""
    failed = False
    failed |= print_errors("TOML contract", validate_repository_manifests())
    failed |= print_errors("Local Markdown links", validate_markdown_links())
    failed |= check_bash_syntax()
    failed |= check_powershell_syntax()
    failed |= run_unit_tests()
    return failed


def main(arguments: list[str] | None = None) -> int:
    """Run every local check, including the sandboxed acceptance suite."""
    arguments = sys.argv[1:] if arguments is None else arguments
    if arguments:
        print("Usage : python tests/acceptance/quality_gate.py", file=sys.stderr)
        return 2

    failed = run_developer_checks()
    failed |= run_command(
        "Sandboxed acceptance suite",
        [sys.executable, "tests/acceptance/parallel_test_runner.py"],
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())