"""Exercise exact-byte restoration and a mid-commit failure in a disposable project."""
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class ConfigurationIOTests(unittest.TestCase):
    def run_fixture(self, fixture):
        godot = os.environ.get("TRIBE_REPLAY_GODOT") or shutil.which("godot") or shutil.which("godot4")
        self.assertIsNotNone(godot, "Godot 4.6.3 is required; this regression must not be skipped")
        with tempfile.TemporaryDirectory(prefix="tribe-config-io-") as directory:
            project = Path(directory)
            (project / "scripts/config").mkdir(parents=True)
            for name in ("config_files.gd", "config_schema.gd"):
                shutil.copy2(ROOT / "scripts/config" / name, project / "scripts/config" / name)
            shutil.copytree(ROOT / "data", project / "data")
            shutil.copy2(ROOT / "tools/tests" / fixture, project / "check.gd")
            (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Configuration IO regression"\n', encoding="utf-8")
            result = subprocess.run([godot, "--headless", "--path", str(project), "--script", "check.gd"],
                                    capture_output=True, text=True, timeout=30,
                                    env={**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1", "XDG_DATA_HOME": str(project / "user-data")})
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIsNone(re.search(r"SCRIPT ERROR:|^ERROR:|^FAIL(?: |:)", output, re.MULTILINE), output)
            return output

    def test_exact_bytes_and_transaction_rollback(self):
        output = self.run_fixture("config_io_fixture.gd")
        self.assertIn("PASS restore preserves exact original SHA including formatting", output)
        self.assertIn("PASS failed multi-file restore rolls back already committed files", output)

    def test_current_chest_grades_have_no_legacy_format(self):
        output = self.run_fixture("config_chests_fixture.gd")
        self.assertIn("PASS all current chest grades validate", output)
        self.assertIn("PASS flat legacy premium chest definition is rejected", output)
        self.assertIn("PASS missing choice chest grade is rejected", output)


if __name__ == "__main__":
    unittest.main()
