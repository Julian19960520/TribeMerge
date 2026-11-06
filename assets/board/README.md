# Baked board art

The board floor, border, rocks, cracks and flying stone fragments are PNG textures.
Gameplay uses texture quads and transforms; it never generates these images at startup.

- `rocks_0..3.png`: four hand-drawn animation phases, 63 variants per atlas, 9 columns of 128 px cells; the 96 px game cell has 16 px padding.
- `frame_0..3.png`: board backing and border, with 20 px padding.
- `floor.png`: white tile tinted for alternating cells, order readiness and cooking.
- `cracks.png`, `fragments.png`: breaking animation overlays and particles.

Regenerate with Godot 4.6.3 on a rendering display:

```
godot --path . --script tools/bake_board.gd -- --cloud-off --save=/tmp/tribe-board-bake.json
godot --headless --editor --path . --import --quit
```

Source geometry is only in `tools/BoardBakeArt.gd`, excluded from Web export.
`tools/check_export_items.gd` validates the actual exported board textures and all 252 rock frames.
