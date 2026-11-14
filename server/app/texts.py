"""Canonical messages shared with the client; the client owns display language."""
from functools import lru_cache
import json
import os
from pathlib import Path


@lru_cache(maxsize=1)
def catalogue() -> dict:
    default = Path(__file__).resolve().parents[2] / "localization/texts.json"
    return json.loads(Path(os.environ.get("TRIBE_TEXTS_FILE", str(default))).read_text(encoding="utf-8"))["entries"]


def source(key: str) -> str:
    return catalogue()[key]["source"]


def hydrate(value):
    if isinstance(value, str) and value.startswith("§") and value.endswith("§"):
        return source(value[1:-1])
    if isinstance(value, list): return [hydrate(entry) for entry in value]
    if isinstance(value, dict): return {key: hydrate(entry) for key, entry in value.items()}
    return value
