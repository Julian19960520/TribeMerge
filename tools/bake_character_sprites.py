"""Crop shared painted portraits into every legacy character sprite alias.

The UI uses the original paintings directly. These compatibility frames also
have to be rebuilt: a cached view, older helper or sprite preview must never
bring the retired monochrome characters back. No drawing engine is required.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "assets/characters/portraits.json"
STAMP = ROOT / "assets/characters/baked_sprites.json"
PNG = ROOT / "assets/sprites/png"
RESAMPLE = Image.Resampling.LANCZOS


def encoded(image: Image.Image) -> bytes:
    output = io.BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


def pixel_hash(data: bytes) -> str:
    image = Image.open(io.BytesIO(data)).convert("RGBA")
    pixels = bytearray(image.tobytes())
    for index in range(0, len(pixels), 4):
        # Godot repairs RGB in nearly transparent edge pixels on import.
        # Retain every alpha byte and compare all clearly visible colors.
        if pixels[index + 3] < 64:
            pixels[index:index + 3] = b"\0\0\0"
    return hashlib.sha256(pixels).hexdigest()


def cropped(image: Image.Image, crop: list[float]) -> Image.Image:
    x, y, width, height = crop
    return image.crop((round(x * image.width), round(y * image.height),
                       round((x + width) * image.width), round((y + height) * image.height)))


def fitted(canvas: Image.Image, art: Image.Image, box: tuple[float, ...]) -> None:
    x, y, width, height = box
    tile = ImageOps.contain(art, (max(1, round(width)), max(1, round(height))), RESAMPLE)
    at = (round(x + (width - tile.width) / 2), round(y + (height - tile.height) / 2))
    canvas.alpha_composite(tile, at)


def avatar(canvas: Image.Image, art: Image.Image, center: tuple[float, float], diameter: float) -> None:
    side = max(1, round(diameter))
    tile = ImageOps.fit(art, (side * 4, side * 4), RESAMPLE)
    mask = Image.new("L", tile.size)
    ImageDraw.Draw(mask).ellipse((0, 0, tile.width - 1, tile.height - 1), fill=255)
    tile.putalpha(ImageChops.multiply(tile.getchannel("A"), mask))
    tile = tile.resize((side, side), RESAMPLE)
    canvas.alpha_composite(tile, (round(center[0] - side / 2), round(center[1] - side / 2)))


def numeric_constant(source: str, name: str) -> float:
    match = re.search(rf"const {name} := ([0-9.]+)", source)
    if match is None:
        raise ValueError(f"Character geometry constant missing: {name}")
    return float(match[1])


def walker_avatar(canvas: Image.Image, art: Image.Image, feet: tuple[float, float],
                  diameter: float, border: float) -> None:
    scale = 4
    layer = Image.new("RGBA", (canvas.width * scale, canvas.height * scale))
    center = (feet[0] * scale, (feet[1] - diameter / 2) * scale)
    draw = ImageDraw.Draw(layer)
    for radius, color in ((diameter / 2 + border, "#3b2314"), (diameter / 2, "#fff7e6")):
        draw.ellipse((center[0] - radius * scale, center[1] - radius * scale,
                      center[0] + radius * scale, center[1] + radius * scale), fill=color)
    avatar(layer, art, center, diameter * scale)
    canvas.alpha_composite(layer.resize(canvas.size, RESAMPLE))


def outputs() -> dict[str, bytes]:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    roles = catalog["roles"]
    characters = catalog["characters"]
    paintings = {key: Image.open(ROOT / row["art"][6:]).convert("RGBA") for key, row in characters.items()}
    heads = {key: cropped(paintings[key], row["avatar"]) for key, row in characters.items()}
    paint_source = (ROOT / "scripts/sprites/paint.gd").read_text(encoding="utf-8")
    tribe_source = (ROOT / "scripts/sprites/tribe.gd").read_text(encoding="utf-8")
    bounds = json.loads(re.search(r"const WALKER_BOUNDS := (\[.*?\])\s*const", tribe_source, re.S)[1])
    meme_source = (ROOT / "scripts/Meme.gd").read_text(encoding="utf-8")
    walker_diameter = numeric_constant(meme_source, "WALKER_DIAMETER")
    walker_border = numeric_constant(meme_source, "WALKER_BORDER")
    hero_width = numeric_constant(paint_source, "W_HERO")
    mascot_scale = numeric_constant(paint_source, "S_MASCOT")
    definitions = {}
    for manifest in (ROOT / "assets/sprites").glob("*.json"):
        definitions.update(json.loads(manifest.read_text(encoding="utf-8")).get("sprites", {}))
    footer = Image.open(ROOT / "assets/characters/duel_entry_footer.png").convert("RGBA")
    result: dict[str, bytes] = {}

    def person(role: int) -> tuple[Image.Image, Image.Image]:
        key = roles[role % len(roles)]
        return paintings[key], heads[key]

    def duel(size: tuple[int, int], gray: bool) -> Image.Image:
        scale = 4
        image = Image.new("RGBA", (size[0] * scale, size[1] * scale))
        image.alpha_composite(footer.resize((footer.width * scale, footer.height * scale), RESAMPLE), (0, 111 * scale))
        draw = ImageDraw.Draw(image)
        for side, role in enumerate((8, 1)):
            cx, cy = (52, 76) if side == 0 else (100, 73)
            def circle(radius: float, color: str, offset: float = 0) -> None:
                draw.ellipse(((cx - radius) * scale, (cy + offset - radius) * scale,
                              (cx + radius) * scale, (cy + offset + radius) * scale), fill=color)
            circle(27, "#00000033", 3)
            circle(27, "#3b2314")
            circle(24.5, "#8cc63f" if side == 0 else "#d2512d")
            circle(20, "#fff7e6")
            avatar(image, person(role)[1], (cx * scale, (cy + 2) * scale), 42 * scale)
        draw = ImageDraw.Draw(image)
        points = []
        for i in range(18):
            angle = -math.pi / 2 + math.pi * i / 9
            radius = 19 if i % 2 == 0 else 13
            points.append(((76 + math.cos(angle) * radius) * scale,
                           (102 + math.sin(angle) * radius) * scale))
        draw.polygon(points, fill="#d2512d")
        draw.line(points + [points[0]], fill="#3b2314", width=3 * scale, joint="curve")
        draw.ellipse((66 * scale, 92 * scale, 86 * scale, 112 * scale), fill="#e8673f")
        font = ImageFont.truetype(str(ROOT / "assets/fonts/NotoSansCJKsc-Regular.otf"), 16 * scale)
        draw.text((76 * scale, 102 * scale), "VS", font=font, anchor="mm", fill="white",
                  stroke_width=2 * scale, stroke_fill="#3b2314")
        image = image.resize(size, RESAMPLE)
        if gray:
            muted = ImageOps.grayscale(image).convert("RGBA")
            muted.putalpha(image.getchannel("A"))
            image = Image.blend(image, muted, 0.62)
        return image

    for key, meta in definitions.items():
        selected = key.startswith(("meme_portrait_", "paint_portrait_", "tribe_walker_")) or key in {
            "paint_hero", "paint_mascot", "paint_mascot_hammer", "ev_entry_duel", "ev_entry_duel_grey"}
        if not selected:
            continue
        pad = int(meta.get("pad", 0))
        width, height = int(meta["w"]), int(meta["h"])
        image = Image.new("RGBA", (width + 2 * pad, height + 2 * pad))
        center = (image.width / 2, image.height / 2)
        if key.startswith("meme_portrait_"):
            role = int(key.rsplit("_", 1)[1])
            avatar(image, person(role)[1], (pad + 92, pad + 124), 140)
        elif key.startswith("paint_portrait_"):
            avatar(image, person(int(key.rsplit("_", 1)[1]))[1], center, 100)
        elif key.startswith("tribe_walker_"):
            role = int(key.rsplit("_", 1)[1])
            old = bounds[role % len(bounds)]
            feet = (pad - old[0] + 3, pad - old[1] + 3)
            walker_avatar(image, person(role)[1], feet, walker_diameter, walker_border)
        elif key == "paint_hero":
            fitted(image, person(8)[0], (center[0] - .6 * hero_width, center[1] - .8 * hero_width,
                                       1.2 * hero_width, 1.6 * hero_width))
        elif key.startswith("paint_mascot"):
            fitted(image, person(9)[0], (center[0] - .48 * mascot_scale, center[1] - .66 * mascot_scale,
                                       .96 * mascot_scale, 1.28 * mascot_scale))
        else:
            image = duel(image.size, key.endswith("_grey"))
        for frame in range(int(meta.get("frames", 1))):
            result[f"assets/sprites/png/{key}_{frame}.png"] = encoded(image)

    # Preserve the original compatibility filenames and dimensions, but retire
    # their monochrome pixels too. The historical source reference stays ignored.
    for name, art in (("caveman_head", heads["hero"]),
                      ("caveman_bust", cropped(paintings["hero"], characters["hero"]["chest"]))):
        path = ROOT / f"assets/meme/{name}.png"
        image = Image.new("RGBA", Image.open(path).size)
        fitted(image, art, (0, 0, image.width, image.height))
        result[path.relative_to(ROOT).as_posix()] = encoded(image)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    pictures = outputs()
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    stamp = {
        "schema": 1,
        "source_sha256": {row["art"][6:]: hashlib.sha256((ROOT / row["art"][6:]).read_bytes()).hexdigest()
                          for row in catalog["characters"].values()},
        "sprites": {path: hashlib.sha256(data).hexdigest() for path, data in sorted(pictures.items())},
        "pixel_sha256": {path: pixel_hash(data) for path, data in sorted(pictures.items())},
    }
    payload = (json.dumps(stamp, ensure_ascii=False, indent=2) + "\n").encode()
    if args.check:
        stale = [path for path, data in pictures.items() if not (ROOT / path).is_file() or (ROOT / path).read_bytes() != data]
        if not STAMP.is_file() or STAMP.read_bytes() != payload:
            stale.append(STAMP.relative_to(ROOT).as_posix())
        if stale:
            raise SystemExit("Character sprites are stale; run python tools/bake_character_sprites.py: " + ", ".join(stale[:8]))
    else:
        for path, data in pictures.items():
            (ROOT / path).write_bytes(data)
        STAMP.write_bytes(payload)
    print(f"PASS {len(pictures)} painted compatibility portraits; no retired monochrome character frames")


if __name__ == "__main__":
    main()
