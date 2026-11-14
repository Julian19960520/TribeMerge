"""Compile public snapshots from the canonical server-owned economy policy."""
from pathlib import Path
import argparse
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))
from app.economy import build

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default=str(ROOT / "server/public"))
    args = parser.parse_args()
    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    for market in ("CN", "US"):
        snapshot = build(market)
        (out / f"catalog_{market}.json").write_text(json.dumps(snapshot, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
        print(f"Economy {market}: {snapshot['version']}, {len(snapshot['items'])} items")
