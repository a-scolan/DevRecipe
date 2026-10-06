"""Scoped Windows maintenance with stateful providers, never real host updates."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from test_baseline import POWERSHELL, REPOSITORY_ROOT, RecipeSandbox, calls_for


PREFLIGHT = """\
function Initialize-DevRecipeWindowsFilesystemCache { param([object[]]$Entries) }
function Find-DevRecipeWindowsOsMetadataEvidence { param([string]$Query); return $false }
"""


def manifest(packages: str = 'git = "latest"', tools: str = "") -> str:
    value = (
        '[metadata]\nschema_version = 2\n[profiles.default]\ndescription = "Maintenance fixture"\n'
        f"[packages.default.os.foundation]\n{packages}\n"
    )
    if tools:
        value += f"[runtimes.default.mise.web]\n{tools}\n"
    return value


def scoop_state(**versions: str) -> str:
    return json.dumps({"apps": [{"Name": name, "Version": version} for name, version in versions.items()]})


def updates(**versions: str) -> str:
    return json.dumps(
        [{"Name": name, "Installed Version": "old", "Latest Version": version, "Info": ""} for name, version in versions.items()]
    )


@unittest.skipUnless(POWERSHELL, "PowerShell unavailable")
class WindowsMaintenanceTests(RecipeSandbox):
    def execute(self, packages='git = "latest"', tools="", fixture=None, arguments=None, prelude=PREFLIGHT):
        return self.run_windows(
            arguments or [],
            manifest_text=manifest(packages, tools),
            fixture=fixture,
            script_prelude=prelude,
        )

    def test_all_installed_packages_and_provider_are_updated_in_order(self):
        execution = self.execute(
            'git = "latest"\ncurl = "latest"',
            fixture={
                "DEVRECIPE_SCOOP_JSON": scoop_state(git="1.0.0", curl="1.0.0", mise="2026.9.3", unrelated="1.0.0"),
                "DEVRECIPE_TEST_SCOOP_UPDATES": updates(git="2.0.0", curl="2.0.0", mise="2026.10.2", unrelated="9.0.0"),
                "DEVRECIPE_TEST_MISE_VERSION": "2026.9.3 windows-x64",
            },
        )
        self.assert_success(execution)
        calls = execution["calls"]
        self.assertLess(calls.index(("scoop", ["update"])), calls.index(("scoop", ["status", "--local"])))
        self.assertLess(calls.index(("scoop", ["update", "mise"])), calls.index(("scoop", ["update", "git"])))
        self.assertIn(["update", "curl"], calls_for(calls, "scoop"))
        self.assertNotIn(["update", "unrelated"], calls_for(calls, "scoop"))
        self.assertNotIn(["update", "*"], calls_for(calls, "scoop"))
        self.assertFalse(any(args[:1] == ["install"] for args in calls_for(calls, "scoop")))
        self.assertIn(["reshim", "--force"], calls_for(calls, "mise"))
        self.assertIsNone(execution["user_path"])

    def test_current_packages_still_trigger_scoop_self_maintenance_without_mise_bootstrap(self):
        execution = self.execute(fixture={"DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0")})
        self.assert_success(execution)
        self.assertIn(["update"], calls_for(execution["calls"], "scoop"))
        self.assertNotIn(["install", "mise"], calls_for(execution["calls"], "scoop"))
        self.assertNotIn(["update", "git"], calls_for(execution["calls"], "scoop"))
        self.assertIn("current | provider=Scoop", execution["result"].stdout)

    def test_aborted_or_failed_git_refresh_stops_update_decisions(self):
        for fixture in (
            {"DEVRECIPE_TEST_STALE_REPOSITORY": r"apps\\scoop"},
            {"DEVRECIPE_TEST_STALE_REPOSITORY": r"buckets\\main"},
            {"DEVRECIPE_TEST_DIRTY_SCOOP": "true"},
            {"DEVRECIPE_TEST_FAIL": "git ls-remote"},
        ):
            with self.subTest(fixture=fixture):
                execution = self.execute(fixture={
                    "DEVRECIPE_SCOOP_JSON": scoop_state(git="1.0.0", mise="2026.9.3"),
                    "DEVRECIPE_TEST_SCOOP_UPDATES": updates(git="2.0.0", mise="2026.10.2"),
                    **fixture,
                })
                self.assertNotEqual(0, execution["result"].returncode)
                self.assertIn("Scoop refresh", execution["result"].stderr)
                self.assertIn(["update"], calls_for(execution["calls"], "scoop"))
                self.assertNotIn(["status", "--local"], calls_for(execution["calls"], "scoop"))
                self.assertFalse(any(len(args) > 1 and args[0] in ("install", "update")
                                     for args in calls_for(execution["calls"], "scoop")))

    def test_fresh_bootstrap_and_approved_git_prerequisite(self):
        prelude = PREFLIGHT + r"""
$global:FixtureScoopBootstrapped = $false
function Get-Command {
    param([string]$Name, $ErrorAction)
    if ($Name -eq 'scoop' -and -not $global:FixtureScoopBootstrapped) { return $null }
    if ($Name -eq 'git') {
        $inventory = Get-Content -LiteralPath $env:DEVRECIPE_TEST_SCOOP_STATE -Raw | ConvertFrom-Json
        if (@($inventory.apps | Where-Object Name -eq 'git').Count -eq 0) { return $null }
    }
    Microsoft.PowerShell.Core\Get-Command @PSBoundParameters
}
function Invoke-RestMethod {
    param($Uri)
    return '$global:FixtureScoopBootstrapped = $true; Add-Content -LiteralPath $env:DEVRECIPE_CALL_LOG -Value "bootstrap`tscoop"'
}
"""
        execution = self.execute(tools='node = "latest"', prelude=prelude, fixture={"DEVRECIPE_TEST_FRESH_BUCKETS": "true"})
        self.assert_success(execution)
        calls = execution["calls"]
        self.assertLess(calls.index(("bootstrap", ["scoop"])), calls.index(("scoop", ["install", "git"])))
        self.assertLess(calls.index(("scoop", ["install", "git"])), calls.index(("scoop", ["update"])))
        self.assertLess(calls.index(("scoop", ["install", "git"])), calls.index(("scoop", ["bucket", "add", "extras"])))
        self.assertIn(["install", "mise"], calls_for(calls, "scoop"))
        self.assertIn(("ipc", ["1.0.0"]), calls)
        execution = self.execute(packages='curl = "latest"', prelude=prelude)
        self.assertNotEqual(0, execution["result"].returncode)
        self.assertIn("requires Git", execution["result"].stderr)
        self.assertNotIn(["update"], calls_for(execution["calls"], "scoop"))

    def test_force_and_skip_preflight_keep_maintenance_without_reinstallation(self):
        for flag in ("-Force", "-SkipPreflight"):
            with self.subTest(flag=flag):
                execution = self.execute(
                    tools='node = "22.0.0"',
                    fixture={
                        "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2"),
                        "DEVRECIPE_MISE_JSON": '{"node":[{"version":"22.0.0","installed":true}]}',
                    },
                    arguments=[flag],
                )
                self.assert_success(execution)
                self.assertIn(["update"], calls_for(execution["calls"], "scoop"))
                self.assertIn(["reshim", "--force"], calls_for(execution["calls"], "mise"))
                self.assertFalse(any(args and args[0] == "install" for _, args in execution["calls"]))

    def test_held_global_duplicate_and_unreported_installed_versions_fail(self):
        for records, available in (
            ([{"Name": "git", "Version": "1.0.0", "Info": "Global install"}], []),
            ([{"Name": "git", "Version": "1.0.0", "Info": "Install failed"}], []),
            ([{"Name": "git", "Version": "1.0.0"}] * 2, []),
            ([{"Name": "git"}], []),
            ([{"Name": "git", "Version": "1.0.0"}],
             [{"Name": "git", "Latest Version": "2.0.0", "Info": "Held package"}]),
        ):
            with self.subTest(records=records, available=available):
                execution = self.execute(fixture={
                    "DEVRECIPE_SCOOP_JSON": json.dumps({"apps": records}),
                    "DEVRECIPE_TEST_SCOOP_UPDATES": json.dumps(available),
                }, arguments=["-SkipPreflight"])
                self.assertNotEqual(0, execution["result"].returncode)
                self.assertNotIn(["update", "git"], calls_for(execution["calls"], "scoop"))
                self.assertNotIn("current | provider=Scoop", execution["result"].stdout)

    def test_malformed_mise_inventory_is_not_treated_as_missing(self):
        for value in ("[]", '{"node":[{}]}', '{"node":[null]}', '{"node":[{"version":"1.0.0","installed":"false"}]}'):
            with self.subTest(value=value):
                execution = self.execute(tools='node = "latest"', fixture={
                    "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2"),
                    "DEVRECIPE_MISE_JSON": value,
                }, arguments=["-SkipPreflight"])
                self.assertNotEqual(0, execution["result"].returncode)
                self.assertIn("Mise inventory", execution["result"].stderr)
                self.assertNotIn(["install", "node@latest"], calls_for(execution["calls"], "mise"))

    def test_pins_are_preserved_while_providers_are_maintained(self):
        execution = self.execute(
            'git = "2.0.0"\nmise = "2026.10.1"',
            'node = "22.0.0"',
            {
                "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.1"),
                "DEVRECIPE_MISE_JSON": '{"node":[{"version":"22.0.0","installed":true}]}',
                "DEVRECIPE_TEST_SCOOP_UPDATES": updates(git="3.0.0", mise="2026.10.2"),
                "DEVRECIPE_TEST_MISE_VERSION": "2026.10.1 windows-x64",
            },
        )
        self.assert_success(execution)
        self.assertIn(["update"], calls_for(execution["calls"], "scoop"))
        self.assertFalse(any(len(args) > 1 and args[0] in ("install", "update") for args in calls_for(execution["calls"], "scoop")))
        self.assertNotIn(["install", "node@22.0.0"], calls_for(execution["calls"], "mise"))
        self.assertIn(("ipc", ["22.0.0"]), execution["calls"])

    def test_floating_requests_resolve_fresh_and_preserve_selector(self):
        for selector in ("latest", "22", "prefix:22", "lts", "lts/jod"):
            with self.subTest(selector=selector):
                execution = self.execute(
                    tools=f'node = "{selector}"',
                    fixture={
                        "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2"),
                        "DEVRECIPE_MISE_JSON": json.dumps({"node": [{"version": "22.0.0", "requested_version": selector, "installed": True}]}),
                        "DEVRECIPE_TEST_MISE_RESOLUTIONS": json.dumps({f"node@{selector}": "22.1.0"}),
                    },
                )
                self.assert_success(execution)
                calls = calls_for(execution["calls"], "mise")
                self.assertIn(["latest", f"node@{selector}"], calls)
                self.assertIn(["install", f"node@{selector}"], calls)
                self.assertIn(("cache", ["0", "true"]), execution["calls"])
                versions = [record["version"] for record in execution["mise_inventory"]["node"]]
                self.assertEqual(["22.0.0", "22.1.0"], versions)
                self.assertFalse(execution["mise_config"])
                self.assertFalse(any(args[0] in ("use", "upgrade", "prune", "self-update") for args in calls if args))

    def test_npm_backend_and_current_resolution_do_not_reinstall(self):
        execution = self.execute(
            tools='"npm:@github/copilot" = "latest"',
            fixture={
                "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2"),
                "DEVRECIPE_MISE_JSON": '{"npm:@github/copilot":[{"version":"1.0.0","installed":true}]}',
            },
        )
        self.assert_success(execution)
        self.assertIn(["latest", "npm:@github/copilot@latest"], calls_for(execution["calls"], "mise"))
        self.assertFalse(any(args[0] == "install" for args in calls_for(execution["calls"], "mise") if args))

    def test_provider_stdout_does_not_corrupt_resolved_runtime_version(self):
        execution = self.execute(tools='node = "latest"', fixture={
            "DEVRECIPE_MISE_INSTALL_STDOUT": "provider normal progress",
        })
        self.assert_success(execution)
        self.assertIn("provider normal progress", execution["result"].stdout)
        self.assertIn(("ipc", ["1.0.0"]), execution["calls"])
        self.assertIn("installed | provider=Scoop | application=git", execution["result"].stdout)

    def test_v_prefixed_exact_pin_uses_canonical_provider_version(self):
        execution = self.execute(tools='node = "v22.0.0"', fixture={
            "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2"),
            "DEVRECIPE_MISE_JSON": '{"node":[{"version":"22.0.0","installed":true}]}',
            "DEVRECIPE_TEST_MISE_RESOLUTIONS": '{"node@v22.0.0":"22.0.0"}',
        }, arguments=["-SkipPreflight"])
        self.assert_success(execution)
        self.assertNotIn(["install", "node@v22.0.0"], calls_for(execution["calls"], "mise"))
        self.assertIn(("ipc", ["22.0.0"]), execution["calls"])

    def test_unsupported_selectors_fail_before_provider_writes(self):
        for selector in ("^22", "~22", "22.*", "22.x", "*", ">=22", "path:node", "system", "ref:main", "sub-2:lts"):
            with self.subTest(selector=selector):
                execution = self.execute(tools=f'node = "{selector}"')
                self.assertNotEqual(0, execution["result"].returncode)
                self.assertIn("selector", execution["result"].stderr)
                self.assertEqual([], execution["calls"])

    def test_failures_do_not_claim_current_or_run_dependent_writes(self):
        for operation in ("scoop update", "scoop status --local", "scoop export", "scoop update git", "scoop info curl --verbose",
                          "mise latest node@latest", "mise install node@latest", "ipc"):
            with self.subTest(operation=operation):
                execution = self.execute(
                    packages='git = "latest"\ncurl = "latest"',
                    tools='node = "latest"',
                    fixture={
                        "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2"),
                        "DEVRECIPE_TEST_FAIL": operation,
                        "DEVRECIPE_TEST_SCOOP_UPDATES": updates(git="3.0.0"),
                    },
                    arguments=["-SkipPreflight"],
                )
                self.assertNotEqual(0, execution["result"].returncode)
                self.assertIn("fail", execution["result"].stderr.lower())
                self.assertNotIn("node-ipc=passed", execution["result"].stdout)
                self.assertIsNone(execution["user_path"])

    def test_post_install_mismatch_is_an_error(self):
        for name in ("curl", "node"):
            with self.subTest(name=name):
                execution = self.execute(
                    'git = "latest"\ncurl = "latest"',
                    'node = "latest"',
                    fixture={
                        "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2"),
                        "DEVRECIPE_TEST_NO_INSTALL": name,
                    },
                )
                self.assertNotEqual(0, execution["result"].returncode)
                self.assertIn("did not establish", execution["result"].stderr)

    def test_provider_shadowing_is_not_automatically_replaced(self):
        execution = self.execute(
            tools='node = "latest"',
            fixture={
                "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.9.3"),
                "DEVRECIPE_TEST_SCOOP_UPDATES": updates(mise="2026.10.2"),
                "DEVRECIPE_TEST_EXTERNAL_MISE": "true",
            },
        )
        self.assertNotEqual(0, execution["result"].returncode)
        self.assertIn("not Scoop-managed", execution["result"].stderr)
        self.assertNotIn(["update", "mise"], calls_for(execution["calls"], "scoop"))
        self.assertFalse(any(args[0] == "install" for args in calls_for(execution["calls"], "mise") if args))

    def test_fixed_node_with_old_mise_requires_provider_upgrade(self):
        execution = self.execute(
            tools='node = "22.0.0"',
            fixture={
                "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.9.3"),
                "DEVRECIPE_TEST_MISE_VERSION": "2026.9.3 windows-x64",
                "DEVRECIPE_TEST_SCOOP_UPDATES": updates(mise="2026.10.1"),
                "DEVRECIPE_MISE_JSON": '{"node":[{"version":"22.0.0","installed":true}]}',
            },
        )
        self.assert_success(execution)
        self.assertIn(["update", "mise"], calls_for(execution["calls"], "scoop"))
        self.assertNotIn(["install", "node@22.0.0"], calls_for(execution["calls"], "mise"))
        self.assertIn(["reshim", "--force"], calls_for(execution["calls"], "mise"))

    def test_explicit_and_multiple_implicit_mise_requests_update_provider_once(self):
        execution = self.execute(
            'git = "latest"\nmise = "latest"',
            'node = "latest"\n"npm:@github/copilot" = "latest"',
            fixture={
                "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.9.3"),
                "DEVRECIPE_TEST_SCOOP_UPDATES": updates(mise="2026.10.2"),
            },
        )
        self.assert_success(execution)
        self.assertEqual(1, calls_for(execution["calls"], "scoop").count(["update", "mise"]))
        self.assertEqual(1, calls_for(execution["calls"], "mise").count(["reshim", "--force"]))

    def test_declined_node_is_not_installed_or_verified(self):
        prelude = PREFLIGHT + """
function Test-DevRecipeInteractiveTerminal { return $true }
function Read-Host { param([string]$Prompt); return 'n' }
"""
        execution = self.execute(tools='node = "22.0.0"', fixture={
            "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2"),
            "DEVRECIPE_MISE_JSON": '{"node":[{"version":"21.0.0","installed":true}]}',
        }, prelude=prelude)
        self.assert_success(execution)
        self.assertIn("decision=decline | application=node", execution["result"].stdout)
        self.assertIn(["update"], calls_for(execution["calls"], "scoop"))
        self.assertFalse(any(provider == "ipc" or (provider == "mise" and args[0] in ("install", "reshim"))
                             for provider, args in execution["calls"] if args))
        self.assertIsNone(execution["user_path"])

    def test_declined_explicit_mise_provider_blocks_dependent_runtime(self):
        prelude = PREFLIGHT + """
function Test-DevRecipeInteractiveTerminal { return $true }
function Read-Host { param([string]$Prompt); return 'n' }
"""
        execution = self.execute(
            'git = "latest"\nmise = "2026.10.1"', 'node = "latest"',
            fixture={"DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.9.3")},
            prelude=prelude,
        )
        self.assertNotEqual(0, execution["result"].returncode)
        self.assertIn("maintenance was declined", execution["result"].stderr)
        self.assertNotIn(["update", "mise"], calls_for(execution["calls"], "scoop"))
        self.assertFalse(any(args and args[0] == "install" for args in calls_for(execution["calls"], "mise")))

    def test_old_or_unknown_mise_release_blocks_node_before_install(self):
        for release in ("2026.9.3 windows-x64", "2026.10.1-rc.1", "unknown"):
            with self.subTest(release=release):
                execution = self.execute(
                    tools='node = "latest"',
                    fixture={
                        "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.9.3"),
                        "DEVRECIPE_TEST_MISE_VERSION": release,
                    },
                )
                self.assertNotEqual(0, execution["result"].returncode)
                self.assertIn("2026.10.1", execution["result"].stderr)
                self.assertNotIn(["install", "node@latest"], calls_for(execution["calls"], "mise"))

    def test_dry_run_keeps_updates_provisional_and_non_mutating(self):
        execution = self.execute(
            tools='node = "22"',
            fixture={
                "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2"),
                "DEVRECIPE_MISE_JSON": '{"node":[{"version":"22.0.0","requested_version":"22","installed":true}]}',
            },
            arguments=["-DryRun"],
        )
        self.assert_success(execution)
        self.assertIn("decision=check-update", execution["result"].stdout)
        self.assertIn("provisional", execution["result"].stdout)
        self.assertIn("scoop update git", execution["result"].stdout)
        for _, args in execution["calls"]:
            self.assertFalse(args and args[0] in ("install", "update", "reshim", "latest"))
        self.assertEqual({}, execution["shell_configs"])
        execution = self.execute(
            fixture={"DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2")},
            arguments=["-DryRun"],
        )
        self.assert_success(execution)
        self.assertIn("mise reshim --force", execution["result"].stdout)
        self.assertFalse(any(args and args[0] in ("install", "update", "reshim") for _, args in execution["calls"]))
        execution = self.execute(packages='git = "2.0.0"', arguments=["-DryRun"])
        self.assert_success(execution)
        self.assertIn("scoop install git@2.0.0 (only when required", execution["result"].stdout)
        execution = self.execute(
            packages='git = "2.0.0"', tools='node = "22.0.0"',
            fixture={
                "DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0", mise="2026.10.2"),
                "DEVRECIPE_MISE_JSON": '{"node":[{"version":"22.0.0","installed":true}]}',
            },
            arguments=["-DryRun"],
        )
        self.assert_success(execution)
        self.assertIn("add the extras bucket if absent", execution["result"].stdout)
        self.assertIn("scoop install mise", execution["result"].stdout)
        self.assertFalse(any(args and args[0] in ("install", "update", "reshim") for _, args in execution["calls"]))

    def test_declining_every_entry_disables_all_maintenance(self):
        prelude = """\
function Test-DevRecipeInteractiveTerminal { return $true }
function Initialize-DevRecipeWindowsFilesystemCache { param([object[]]$Entries) }
function Find-DevRecipeWindowsOsMetadataEvidence { param([string]$Query); return $true }
function Invoke-NativeMultiSelect { param([object[]]$Entries); return [PSCustomObject]@{Cancelled=$true; Selected=@($false)} }
function Read-Host { param([string]$Prompt); return 'D' }
"""
        execution = self.execute(prelude=prelude)
        self.assert_success(execution)
        self.assertIn(["update"], calls_for(execution["calls"], "scoop"))
        self.assertFalse(any(len(args) > 1 and args[0] in ("install", "update") for args in calls_for(execution["calls"], "scoop")))
        self.assertIn("No approved entries remain", execution["result"].stdout)

    def test_review_refusal_happens_before_scoop_self_update(self):
        prelude = PREFLIGHT + """\
function Test-DevRecipeInteractiveTerminal { return $true }
function Read-Host { param([string]$Prompt); return 'n' }
"""
        execution = self.execute(
            fixture={"DEVRECIPE_SCOOP_JSON": scoop_state(git="2.0.0")},
            arguments=["-Review"],
            prelude=prelude,
        )
        self.assertEqual(3, execution["result"].returncode)
        self.assertNotIn(["update"], calls_for(execution["calls"], "scoop"))

    def test_individual_review_approvals_and_provider_update_refusal(self):
        prelude = PREFLIGHT + """
function Test-DevRecipeInteractiveTerminal { return $true }
function Read-Host {
    param([string]$Prompt)
    if ($env:DEVRECIPE_TEST_REJECT_MISE -eq 'true' -and $script:DevRecipeReviewActionNumber -eq 2) { return 'n' }
    return 'y'
}
"""
        fixture = {
            "DEVRECIPE_SCOOP_JSON": scoop_state(git="1.0.0", mise="2026.9.3"),
            "DEVRECIPE_TEST_SCOOP_UPDATES": updates(git="2.0.0", mise="2026.10.2"),
        }
        execution = self.execute(fixture=fixture, arguments=["-Review"], prelude=prelude)
        self.assert_success(execution)
        self.assertNotIn("approval: all remaining", execution["result"].stdout)
        calls = calls_for(execution["calls"], "scoop")
        self.assertLess(calls.index(["update"]), calls.index(["update", "mise"]))
        self.assertLess(calls.index(["update", "mise"]), calls.index(["update", "git"]))
        execution = self.execute(
            fixture={**fixture, "DEVRECIPE_TEST_REJECT_MISE": "true"}, arguments=["-Review"], prelude=prelude,
        )
        self.assertEqual(3, execution["result"].returncode)
        self.assertIn(["update"], calls_for(execution["calls"], "scoop"))
        self.assertNotIn(["update", "mise"], calls_for(execution["calls"], "scoop"))
        self.assertNotIn(["update", "git"], calls_for(execution["calls"], "scoop"))

    def test_release_order_and_selector_helpers(self):
        source = (REPOSITORY_ROOT / "DevRecipe_windows.ps1").read_text(encoding="utf-8-sig")
        helpers = source[source.index("function Get-DevRecipeMiseSelectorKind"):source.index("# End Windows maintenance helpers.")]
        with tempfile.TemporaryDirectory(prefix="devrecipe-release-") as directory:
            probe = Path(directory) / "probe.ps1"
            probe.write_text(
                "$ErrorActionPreference='Stop'\n" + helpers + """
foreach ($v in '2026.10.1 windows-x64','2026.10.2','2026.10.10','2026.11.0','2027.1.0') { Assert-DevRecipeNodeMiseVersion $v }
if ((Get-DevRecipeMiseSelectorKind '22') -ne 'floating') { throw 'partial pin error' }
if ((Get-DevRecipeMiseSelectorKind '22.0.0') -ne 'exact') { throw 'exact pin error' }
if ((Get-DevRecipeMiseSelectorKind '2026-10-release') -ne 'floating') { throw 'opaque request error' }
""",
                encoding="utf-8",
            )
            result = subprocess.run([POWERSHELL, "-NoProfile", "-File", str(probe)], text=True, capture_output=True)
            self.assertEqual(0, result.returncode, result.stderr)


if __name__ == "__main__":
    unittest.main()
