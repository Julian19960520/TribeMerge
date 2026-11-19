"""Canonical messages shared with the client; the client owns display language."""
from functools import lru_cache
import json
import os
from pathlib import Path
import re

_SLOT = re.compile(r"\$\{(\d+)\}")


def _entries(path: Path) -> dict:
    document = json.loads(path.read_text(encoding="utf-8"))
    if "files" not in document:
        return document["entries"]
    entries = {}
    for relative in document["files"]:
        file = path.parent / relative
        part = json.loads(file.read_text(encoding="utf-8"))
        feature = str(part.get("feature") or file.stem)
        prefix = f"{file.parent.name}.{feature}."
        for local, entry in part["entries"].items():
            entries[local if local.startswith(prefix) else prefix + local] = entry
    return entries


@lru_cache(maxsize=1)
def catalogue() -> dict:
    default = Path(__file__).resolve().parents[2] / "localization/texts.json"
    return _entries(Path(os.environ.get("TRIBE_TEXTS_FILE", str(default))))


def source(key: str) -> str:
    return catalogue()[key]["zh_CN"]


def fill(template: str, arguments=None) -> str:
    if arguments is None:
        return template
    values = arguments if isinstance(arguments, (list, tuple)) else (arguments,)
    def replace(match):
        index = int(match.group(1))
        return str(values[index]) if 0 <= index < len(values) else match.group(0)
    return _SLOT.sub(replace, template)


def hydrate(value):
    if isinstance(value, str) and value.startswith("§") and value.endswith("§"):
        return source(value[1:-1])
    if isinstance(value, list): return [hydrate(entry) for entry in value]
    if isinstance(value, dict): return {key: hydrate(entry) for key, entry in value.items()}
    return value
