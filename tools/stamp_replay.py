"""Stamp the current pure gameplay dependency graph, shared by clients and workers.

The graph follows preload/load/extends paths and class_name references. Entire rule
namespaces are roots, so a new helper is included without maintaining a file list.
Presentation, persistence and transport do not change gameplay identity.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RULE_DIRECTORIES = ("scripts/domain", "scripts/config", "scripts/merge", "scripts/events")
ENTRYPOINTS = ("scripts/Game.gd", "scripts/Data.gd", "scripts/replay/Reducer.gd")
EXCLUDED_DIRECTORIES = ("scripts/ui/", "scripts/preview/", "scripts/sprites/", "scripts/net/", "scripts/storage/")
EXCLUDED_FILES = {
    "scripts/Main.gd", "scripts/Sfx.gd", "scripts/Sprites.gd", "scripts/ItemAnim.gd",
    "scripts/Art.gd", "scripts/Paint.gd", "scripts/Meme.gd", "scripts/TribeArt.gd",
    "scripts/BakeItems.gd", "scripts/BakeSprites.gd", "scripts/TextureCache.gd",
    "scripts/replay/Replay.gd", "scripts/replay/Journal.gd", "scripts/replay/worker.gd",
}
PATH_REFERENCE = re.compile(r'''(?:preload|load)\s*\(\s*["']res://([^"']+\.gd)["']|extends\s+["']res://([^"']+\.gd)["']''')
CLASS_NAME = re.compile(r"^\s*class_name\s+(\w+)", re.MULTILINE)
IDENTIFIER = re.compile(r"\b[A-Za-z_]\w*\b")


def is_rule_source(relative: str) -> bool:
    return relative.endswith(".gd") and relative not in EXCLUDED_FILES and not relative.startswith(EXCLUDED_DIRECTORIES)


def rule_sources(root: Path = ROOT) -> list[Path]:
    sources = {path.relative_to(root).as_posix(): path.read_text(encoding="utf-8")
               for path in (root / "scripts").rglob("*.gd")}
    classes = {match.group(1): relative for relative, source in sources.items()
               if (match := CLASS_NAME.search(source))}
    required = set(ENTRYPOINTS)
    required.update(relative for relative in sources
                    if any(relative.startswith(directory + "/") for directory in RULE_DIRECTORIES))
    pending = list(required)
    visited: set[str] = set()
    while pending:
        relative = pending.pop()
        if relative in visited or not is_rule_source(relative):
            continue
        if relative not in sources:
            raise FileNotFoundError(f"Gameplay source missing: {relative}")
        visited.add(relative)
        source = sources[relative]
        dependencies = {first or second for first, second in PATH_REFERENCE.findall(source)}
        identifiers = IDENTIFIER.findall(re.sub(r"#[^\n]*", "", source))
        dependencies.update(classes[name] for name in identifiers if name in classes)
        pending.extend(dependency for dependency in dependencies if is_rule_source(dependency))
    return [root / relative for relative in sorted(visited)]


def manifest(root: Path = ROOT) -> dict:
    digest = hashlib.sha256()
    paths = rule_sources(root)
    for path in paths:
        digest.update(path.relative_to(root).as_posix().encode() + b"\0" + path.read_bytes() + b"\0")
    return {"protocol": 1, "godot": "4.6.3", "code_sha256": digest.hexdigest(),
            "sources": [path.relative_to(root).as_posix() for path in paths]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if the stamped rule sources changed")
    args = parser.parse_args()
    target = ROOT / "data/replay_build.json"
    content = json.dumps(manifest(), indent=2) + "\n"
    if args.check:
        if not target.exists() or target.read_text(encoding="utf-8") != content:
            raise SystemExit("Rule fingerprint is stale; run python tools/stamp_replay.py")
    else:
        if not target.exists() or target.read_text(encoding="utf-8") != content:
            temporary = target.with_suffix(".json.tmp")
            temporary.write_text(content, encoding="utf-8")
            temporary.replace(target)


if __name__ == "__main__":
    main()
