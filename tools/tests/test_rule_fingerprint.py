"""Rule identity follows helper dependencies and excludes presentation/runtime plumbing."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("stamp_replay", Path(__file__).resolve().parents[1] / "stamp_replay.py")
stamp = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(stamp)


class RuleFingerprintTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.write("scripts/Game.gd", 'extends Node\nconst Helper = preload("res://scripts/helper.gd")\n')
        self.write("scripts/Data.gd", "class_name Data\nextends RefCounted\n")
        self.write("scripts/replay/Reducer.gd", "extends RefCounted\n")
        self.write("scripts/helper.gd", "extends RefCounted\nconst VALUE = 1\n")
        self.write("scripts/ui/Screen.gd", "class_name Screen\nextends Control\n")
        self.write("scripts/replay/worker.gd", "extends SceneTree\n")

    def tearDown(self):
        self.temporary.cleanup()

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def test_nested_preload_helper_changes_identity(self):
        before = stamp.manifest(self.root)["code_sha256"]
        self.write("scripts/helper.gd", 'extends RefCounted\nconst Nested = preload("res://scripts/nested.gd")\n')
        self.write("scripts/nested.gd", "extends RefCounted\nconst VALUE = 2\n")
        after = stamp.manifest(self.root)
        self.assertNotEqual(before, after["code_sha256"])
        self.assertIn("scripts/nested.gd", after["sources"])

    def test_new_namespace_helper_is_automatically_included(self):
        before = stamp.manifest(self.root)["code_sha256"]
        self.write("scripts/domain/Rule.gd", "extends RefCounted\nconst VALUE = 3\n")
        self.assertNotEqual(before, stamp.manifest(self.root)["code_sha256"])

    def test_class_name_dependency_is_included(self):
        self.write("scripts/helper.gd", "extends RefCounted\nfunc value(): return RuleHelper.VALUE\n")
        self.write("scripts/nested.gd", "class_name RuleHelper\nextends RefCounted\nconst VALUE = 4\n")
        self.assertIn("scripts/nested.gd", stamp.manifest(self.root)["sources"])

    def test_ui_worker_and_transport_do_not_change_identity(self):
        before = stamp.manifest(self.root)
        self.write("scripts/ui/Screen.gd", "class_name Screen\nextends Control\nconst COLOR = 7\n")
        self.write("scripts/replay/worker.gd", "extends SceneTree\nconst PROTOCOL = 10\n")
        self.write("scripts/net/Cloud.gd", "extends Node\n")
        self.assertEqual(before, stamp.manifest(self.root))

    def test_missing_gameplay_dependency_fails(self):
        self.write("scripts/helper.gd", 'extends RefCounted\nconst Missing = preload("res://scripts/missing.gd")\n')
        with self.assertRaises(FileNotFoundError):
            stamp.manifest(self.root)

    def test_manifest_is_deterministic(self):
        self.assertEqual(stamp.manifest(self.root), stamp.manifest(self.root))
        self.assertEqual(stamp.manifest(self.root)["sources"], sorted(stamp.manifest(self.root)["sources"]))


if __name__ == "__main__":
    unittest.main()
