# Baked board art

The board floor, border, rocks, cracks and flying stone fragments are PNG textures.
Gameplay uses texture quads and transforms; it never generates these images at startup.

- `rocks_0..3.png`: four hand-drawn line-boil phases, 63 variants per atlas (one per board cell), 9 columns of 128 px cells; the 96 px game cell has 16 px padding. Each variant picks one of 4 silhouettes (round boulder, stacked pair, flat slab with a stone on top, leaning standing stone), one of 4 stone palettes, and optional moss cap, grass tuft, flower, mushroom, pebble and lichen spots, so neighbouring cells never repeat.
- `frame_0..3.png`: board backing and border, with 20 px padding.
- `floor.png`: 4 white floor tiles in a row (384 × 96), tinted at runtime for alternating cells, order readiness and cooking; `Board._floor_region` staggers them.
- `cracks.png`, `fragments.png`: breaking animation overlays and particles.

Regenerate with Godot 4.6.3 on a rendering display (add `--dir=<folder>` to bake somewhere else for a preview):

```
godot --path . --script tools/bake_board.gd -- --cloud-off --save=/tmp/tribe-board-bake.json
godot --headless --editor --path . --import --quit
```

Source geometry is only in `tools/BoardBakeArt.gd`, excluded from Web export.
`tools/check_export_items.gd` validates the actual exported board textures and all 252 rock frames.
