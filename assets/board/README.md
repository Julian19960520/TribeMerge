# Baked board art

The board floor, border, locked-cell forest, its breaking overlay and flying leaves are PNG textures.
Gameplay uses texture quads and transforms; it never generates these images at startup.

- `rocks_0..3.png`: locked-cell trees in the tribe-screen tree style (`BoardBakeArt.forest`, same look as `Paint.forest_tree`: no ink line, trunk + three canopy greens), transparent; four line-boil phases, 63 single-tree variants per atlas, 9 columns of 128 px tiles, tree root at (64, 112) of each tile, baked at `FOREST_TILE_SCALE`. The board does not draw one tile per cell any more: `scripts/ui/board/ForestLayout.gd` scatters tree roots over the whole board on a jittered, staggered grid that ignores cell borders (fixed seed), each tree belongs to the cell under its root, trees next to an open cell or the board edge are pulled in / shrunk a little, and all locked cells' trees are sorted by root height before drawing. The old boulder art (`BoardBakeArt.rock`) is kept for reference but no longer baked.
- `forest_ground.png`: the grass patch under each locked cell, same atlas layout (one tile per cell). The board draws every locked cell's grass first, then every cell's trees, so grass never covers the canopies of the row above.
- `frame_0..3.png`: board backing and border, with 20 px padding.
- `floor.png`: 4 white floor tiles in a row (384 × 96), tinted at runtime for alternating cells, order readiness and cooking; `Board._floor_region` staggers them.
- `cracks.png`, `fragments.png`: breaking animation overlay (leaves rustling, `rustle`) and flying particles (leaves, twigs, a green puff, `leaf_fragment`). The file names stay from the boulder days.

Regenerate with Godot 4.6.3 on a rendering display (add `--dir=<folder>` to bake somewhere else for a preview):

```
godot --path . --script tools/bake_board.gd -- --cloud-off --save=/tmp/tribe-board-bake.json
godot --headless --editor --path . --import --quit
```

Source geometry is only in `tools/BoardBakeArt.gd`, excluded from Web export.
`tools/check_export_items.gd` validates the actual exported board textures and all 252 rock frames.
