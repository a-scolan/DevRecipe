"""Opt-in actual native shim checks in disposable Mise configuration and data."""

import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest

from test_baseline import POWERSHELL, REPOSITORY_ROOT


@unittest.skipUnless(
    POWERSHELL and os.name == "nt" and os.environ.get("DEVRECIPE_NATIVE_MISE_FIXED") and os.environ.get("DEVRECIPE_NATIVE_NODE"),
    "Set DEVRECIPE_NATIVE_MISE_FIXED and DEVRECIPE_NATIVE_NODE for isolated native IPC checks",
)
class NativeWindowsIpcTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._kill_mise()

    @classmethod
    def tearDownClass(cls):
        cls._kill_mise()

    def setUp(self):
        self._kill_mise()

    def tearDown(self):
        self._kill_mise()

    @staticmethod
    def _kill_mise():
        if sys.platform == "win32":
            try:
                subprocess.run(
                    ["taskkill", "/F", "/IM", "mise.exe", "/T"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )
            except Exception:
                pass

    def native_probe(self, mise_binary, *, shim_binary=None, rebuild=False, fault=None, installed_version=None):
        node = Path(os.environ["DEVRECIPE_NATIVE_NODE"])
        source = (REPOSITORY_ROOT / "DevRecipe_windows.ps1").read_text(encoding="utf-8-sig")
        helpers = source[source.index("function Get-DevRecipeMiseSelectorKind"):source.index("# End Windows maintenance helpers.")]
        with tempfile.TemporaryDirectory(prefix="devrecipe-native-ipc-") as directory:
            root = Path(directory)
            data = root / "data"
            version = subprocess.check_output([str(node), "-p", "process.versions.node"], text=True).strip()
            installation = data / "installs" / "node" / version
            installation.mkdir(parents=True)
            shutil.copy2(node, installation / "node.exe")
            config = root / "mise.toml"
            config.write_text(
                f"[tools]\nnode = '{version}'\n[settings]\nwindows_shim_mode = 'exe'\nshims_dir = '{data / 'shims'}'\n",
                encoding="utf-8",
            )
            environment = {key: value for key, value in os.environ.items() if not key.lstrip("_").startswith("MISE_")}
            environment.update({
                "MISE_DATA_DIR": str(data),
                "MISE_CACHE_DIR": str(root / "cache"),
                "MISE_CONFIG_DIR": str(root / "config"),
                "MISE_GLOBAL_CONFIG_FILE": str(config),
                "MISE_SYSTEM_CONFIG_FILE": str(root / "system.toml"),
                "MISE_SYSTEM_CONFIG_DIR": str(root / "system"),
                "MISE_GLOBAL_CONFIG_ROOT": str(root),
                "MISE_CEILING_PATHS": str(root.parent),
                "MISE_BIN": str(mise_binary),
                "MISE_TRUSTED_CONFIG_PATHS": str(root),
                "MISE_YES": "true",
                "MISE_OFFLINE": "true",
                "MISE_STATE_DIR": str(root / "state"),
                "MISE_TMP_DIR": str(root / "tmp"),
                "LOCALAPPDATA": str(root / "local"),
                "APPDATA": str(root / "roaming"),
                "USERPROFILE": str(root / "home"),
                "HOME": str(root / "home"),
                "XDG_CONFIG_HOME": str(root / "config"),
                "XDG_DATA_HOME": str(data),
                "XDG_CACHE_HOME": str(root / "cache"),
                "TEMP": str(root),
                "TMP": str(root),
            })
            mise_version = subprocess.check_output(
                [str(mise_binary), "--version"], cwd=root, env=environment, text=True,
            ).strip()
            shim_source = shim_binary or mise_binary
            built = subprocess.run(
                [str(shim_source), "reshim", "--force"], cwd=root, env={**environment, "MISE_BIN": str(shim_source)},
                text=True, capture_output=True, timeout=30,
            )
            self.assertEqual(0, built.returncode, built.stdout + built.stderr)
            shim = data / "shims" / "node.exe"
            self.assertTrue(shim.is_file(), built.stdout + built.stderr + repr(list(root.rglob("*"))))
            self.assertEqual(
                (Path(shim_source).parent / "mise-shim.exe").read_bytes(), shim.read_bytes(),
                "Native control did not copy the requested release's executable shim",
            )
            if rebuild:
                repaired = subprocess.run(
                    [str(mise_binary), "reshim", "--force"], cwd=root, env=environment,
                    text=True, capture_output=True, timeout=30,
                )
                self.assertEqual(0, repaired.returncode, repaired.stdout + repaired.stderr)
                self.assertEqual((Path(mise_binary).parent / "mise-shim.exe").read_bytes(), shim.read_bytes())
            if fault == "spawn":
                shim.write_bytes(b"invalid executable")
            elif fault == "missing":
                shim.unlink()
            elif fault == "selection":
                config.write_text("[settings]\nwindows_shim_mode = 'exe'\n", encoding="utf-8")
            elif fault in ("timeout", "reply", "exit", "channel"):
                hook = root / "child-hook.cjs"
                action = {
                    "timeout": "process.send = () => {};",
                    "reply": "const send = process.send; process.send = (m, cb) => send.call(process, {...m, token:'invalid'}, cb);",
                    "exit": "process.exit(7);",
                    "channel": "",
                }[fault]
                if fault == "channel":
                    action = (
                        "if (!process.send) { const cp = require('node:child_process'); const spawn = cp.spawn;"
                        " cp.spawn = (...args) => { const child = spawn(...args);"
                        " child.send = (m, cb) => cb(new Error('closed channel')); return child; }; }\n"
                    )
                else:
                    action = "if (process.send) { " + action + " }\n"
                hook.write_text(action, encoding="utf-8")
                escaped_hook = str(hook).replace("\\", "\\\\")
                environment["NODE_OPTIONS"] = f'--require "{escaped_hook}"'
            expected_config = config.read_bytes()
            probe = root / "probe.ps1"
            probe.write_text(
                "$ErrorActionPreference='Stop'\n" + helpers +
                f"\nfunction Get-DevRecipeMiseShimsPath {{ return '{shim.parent}' }}\n" +
                f"function Get-DevRecipeProviderText {{ param($Provider,$Arguments); return '{node.parent}' }}\n" +
                f"Assert-DevRecipeNodeMiseVersion -VersionText '{mise_version}'\n" +
                f"Test-DevRecipeNodeShimIpc -InstalledVersion '{installed_version or version}'\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [POWERSHELL, "-NoProfile", "-File", str(probe)], cwd=root, env=environment,
                text=True, errors="replace", capture_output=True, timeout=60,
            )
            self.assertEqual([], list(root.glob("devrecipe-ipc-*.cjs")), "Temporary IPC probe was not removed")
            self.assertEqual(expected_config, config.read_bytes(), "IPC verification rewrote version selection")
            processes = subprocess.run(
                [POWERSHELL, "-NoProfile", "-Command",
                 f"Get-CimInstance Win32_Process | Where-Object {{ $_.ProcessId -ne $PID -and $_.ExecutablePath -like '{root}\\*' }} | ForEach-Object ProcessId"],
                text=True, capture_output=True, timeout=30,
            )
            self.assertEqual(0, processes.returncode, processes.stderr)
            self.assertEqual("", processes.stdout.strip(), "Isolated probe left child processes running")
            return result

    def test_fixed_native_shim_transfers_ipc(self):
        result = self.native_probe(os.environ["DEVRECIPE_NATIVE_MISE_FIXED"])
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("node-ipc=passed", result.stdout)
        self.assertIn("executable=", result.stdout)
        self.assertIn("installed=" + subprocess.check_output(
            [os.environ["DEVRECIPE_NATIVE_NODE"], "-p", "process.versions.node"], text=True,
        ).strip(), result.stdout)

    def test_distinct_faults_and_cleanup_preserve_unrelated_node(self):
        unrelated = subprocess.Popen(
            [os.environ["DEVRECIPE_NATIVE_NODE"], "-e", "setInterval(() => {}, 1000)"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        try:
            for fault, message in (
                ("timeout", "timed out after 5000 ms"),
                ("reply", "Invalid Node shim IPC reply"),
                ("exit", "exited without successful IPC"),
                ("spawn", "spawn failed"),
                ("channel", "IPC channel failed"),
                ("missing", "Node shim is missing"),
                ("selection", "IPC"),
            ):
                with self.subTest(fault=fault):
                    result = self.native_probe(os.environ["DEVRECIPE_NATIVE_MISE_FIXED"], fault=fault)
                    self.assertNotEqual(0, result.returncode, result.stdout)
                    self.assertIn(message, result.stderr)
                    self.assertNotIn("node-ipc=passed", result.stdout)
                    self.assertIsNone(unrelated.poll(), "Probe terminated an unrelated Node process")
        finally:
            unrelated.terminate()
            unrelated.wait(timeout=10)

    def test_active_version_is_reported_without_changing_selection(self):
        result = self.native_probe(
            os.environ["DEVRECIPE_NATIVE_MISE_FIXED"], installed_version="0.0.0",
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("installed=0.0.0", result.stdout)
        self.assertIn("installed and active versions differ", result.stdout)

    @unittest.skipUnless(os.environ.get("DEVRECIPE_NATIVE_MISE_AFFECTED"), "Affected Mise executable unavailable")
    def test_positive_control_rejects_old_provider(self):
        result = self.native_probe(os.environ["DEVRECIPE_NATIVE_MISE_AFFECTED"])
        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("below 2026.10.1", result.stderr)

    @unittest.skipUnless(os.environ.get("DEVRECIPE_NATIVE_MISE_AFFECTED"), "Affected Mise executable unavailable")
    def test_forced_rebuild_repairs_stale_native_shim(self):
        result = self.native_probe(
            os.environ["DEVRECIPE_NATIVE_MISE_FIXED"],
            shim_binary=os.environ["DEVRECIPE_NATIVE_MISE_AFFECTED"], rebuild=True,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("node-ipc=passed", result.stdout)

    @unittest.skipUnless(os.environ.get("DEVRECIPE_NATIVE_MISE_AFFECTED"), "Affected Mise executable unavailable")
    def test_affected_native_shim_is_detected_and_cleaned_up(self):
        result = self.native_probe(
            os.environ["DEVRECIPE_NATIVE_MISE_FIXED"],
            shim_binary=os.environ["DEVRECIPE_NATIVE_MISE_AFFECTED"],
        )
        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("IPC", result.stderr)
        self.assertNotIn("node-ipc=passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
