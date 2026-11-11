"""Exercise the real configuration Save callback in an isolated project copy."""
from __future__ import annotations
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    arguments = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="tribe-config-ui-") as temporary:
        project = Path(temporary)
        for filename in ("project.godot", "main.tscn"):
            shutil.copy2(source / filename, project / filename)
        shutil.copytree(source / "data", project / "data")
        for folder in ("scripts", "tools", "assets", "shaders"):
            (project / folder).symlink_to(source / folder, target_is_directory=True)
        cache = project / ".godot"
        cache.mkdir()
        for filename in ("global_script_class_cache.cfg", "uid_cache.bin"):
            if (source / ".godot" / filename).exists():
                shutil.copy2(source / ".godot" / filename, cache / filename)
        (cache / "imported").symlink_to(source / ".godot/imported", target_is_directory=True)
        return subprocess.run([
            arguments.godot, "--headless", "--path", str(project), "--script",
            "res://tools/check_config_editor_save.gd", "--", "--replay-test", "--cloud-off",
            f"--save={project / 'player.json'}", f"--cloud-state={project / 'cloud.json'}",
            f"--config-test-root={project}",
        ], check=False, timeout=60).returncode


if __name__ == "__main__":
    raise SystemExit(main())
