"""Bake opened chest frames from the existing procedural art, without a display."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

import cairosvg

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="tribe-open-chests-") as directory:
        subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--script",
                        "tools/bake_open_chests.gd", "--", "--replay-test", "--cloud-off",
                        f"--out={directory}", f"--save={directory}/save.json"], check=True)
        files = sorted(Path(directory).glob("*_open_r*.svg"))
        if not files:
            raise SystemExit("No opened chest art was recorded")
        for source in files:
            cairosvg.svg2png(url=str(source), write_to=str(ROOT / "assets/items/png" / (source.stem + ".png")))
        manifest = ROOT / "assets/items/anim.json"
        data = json.loads(manifest.read_text())
        ids = sorted({source.stem.split("_r")[0] for source in files})
        data["ids"].extend(value for value in ids if value not in data["ids"])
        manifest.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
        print(f"PASS baked {len(files)} opened chest frames")


if __name__ == "__main__":
    main()
