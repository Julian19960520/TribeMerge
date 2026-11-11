"""Build the independent verification manifest from the actual export preset."""
import configparser
import fnmatch
from pathlib import Path


def manifest(root: Path) -> dict:
    settings = configparser.ConfigParser(interpolation=None)
    settings.read(root / "export_presets.cfg")
    excluded = settings['preset.0']['exclude_filter'].strip('"').split(',')
    def omitted(path):
        return any(fnmatch.fnmatchcase(path, pattern) for pattern in excluded)
    scripts = sorted("res://" + path.relative_to(root).as_posix()
                     for path in (root / "scripts").rglob("*.gd")
                     if not omitted(path.relative_to(root).as_posix()))
    forbidden = sorted("res://" + path.relative_to(root).as_posix()
                       for path in root.rglob("*")
                       if path.is_file() and path.suffix in (".gd", ".tscn", ".png")
                       and not any(part in (".git", ".godot", "dist") for part in path.relative_to(root).parts)
                       and omitted(path.relative_to(root).as_posix()))
    return {"scripts": scripts, "excluded": forbidden}
