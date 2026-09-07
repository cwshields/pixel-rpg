# Shaders

## `foliage_wind.gdshader`

A reusable canvas_item **vertex** shader that sways foliage in the wind —
grass tiles, bushes, crops, tree canopies. It only displaces geometry; the
sprite's pixels are untouched.

### Shared wind field (project shader-globals)

Two parameters are declared in `project.godot` under `[shader_globals]` so
every material using this shader reads the same wind:

| global          | type  | meaning                                             |
| --------------- | ----- | -------------------------------------------------- |
| `wind_direction`| vec2  | world-space push direction (magnitude scales it)   |
| `wind_strength` | float | global multiplier; `0.0` = dead calm               |

Tune them in **Project Settings → Shader Globals**, or drive them at
runtime (gusts, storms) from code:

```gdscript
RenderingServer.global_shader_parameter_set("wind_strength", 2.0)
```

### How the base stays pinned

The shader keys off `VERTEX_ID`, not `UV`: the two **bottom** vertices of
each quad (trunk / stem base) get zero offset, the two **top** vertices get
the full offset, and the GPU shears the image linearly between them. This is
why it works identically on a `Sprite2D` and on a batched `TileMapLayer` —
`UV` on a tilemap is atlas-space and can't locate you inside a tile, but
`VERTEX_ID` always can.

A plain quad has only those four corners, so the bend between base and top
is a straight line — the lower trunk leans slightly rather than staying
perfectly rigid for its lower half. At 1–3 px amplitude that's invisible.
If you need a genuinely stiff lower trunk with movement only up in the
crown, split the art so the trunk is its own static sprite and put the wind
material only on the canopy sprite (a single quad can't curve).

### Per-material parameters

`sway_strength` (px at the top edge), `sway_speed`, `gust_speed` (slow
amplitude swell), `pixel_snap` (round the offset to whole pixels — on by
default to match the project's nearest filter), `invert_pivot` (flip if a
particular sprite/tileset sways from its bottom instead of its top, i.e. its
vertex winding differs from the assumed `0=TL, 1=BL, 2=BR, 3=TR`).

### Attaching it

Anything that should sway needs a `ShaderMaterial` pointing at this shader
on its own `CanvasItem`. Two tuned material resources exist; reuse one or
add another:

| material                                             | tuned for            |
| --------------------------------------------------- | -------------------- |
| `resources/materials/foliage_wind_material.tres`     | 16 px grass / tufts  |
| `resources/materials/foliage_wind_tree_material.tres`| big tree canopy art  |

- **TileMapLayer** (e.g. `World/TileMap/Vegitation` in `scenes/main.tscn`):
  set the layer's `material`. Every tile pins its own bottom edge and sways
  its top, phase-varied by world position.
- **Sprite2D** prop (e.g. the `Sprite2D` in `scenes/world/tree.tscn`): give
  it its own `ShaderMaterial` with this shader — works for a centered sprite
  or an `AtlasTexture` with no extra setup. The vertex sway composes fine
  with the CPU `modulate.a` proximity fade on the same sprite.
- Sharing one material across many instances is safe — the shader has no
  per-instance state.

### Excluding individual tiles from the layer's wind

A material on a `TileMapLayer` applies to every tile it draws, but
`TileData.material` (per tile, in the TileSet editor under **Rendering →
Material**) *overrides* the layer material for that one tile. To opt a tile
out of the wind, assign it `resources/materials/static_prop_material.tres`
(a bare `CanvasItemMaterial` — renders exactly like no material, just isn't
the wind shader).

This is already done for the **tree-stump tiles** and the **bare "stick"
tiles** (leafless / frosted dead trees — columns 3 & 4 of each tree sheet)
in `TileSet_st1fa` (the `Vegitation` layer's tileset):

| tileset atlas source     | stump tiles                     | bare "stick" tiles                     |
| ------------------------ | ------------------------------- | -------------------------------------- |
| Size_02 (`...u8var`)     | —                               | `14:0`, `14:5`, `18:1`, `18:4`         |
| Size_03 (`...h73ol`)     | `12:0`, `12:2`, `12:4`          | `6:0`, `6:6`, `9:0`, `9:6`             |
| Size_04 (`...mqqvp`)     | `20:0`, `20:2`, `20:4`, `20:6`  | `10:0`, `10:8`, `15:0`, `15:8`         |
| Size_05 (`...p6oml`)     | `1:20`, `8:20`, `15:20`, `22:20`| `14:0`, `14:10`, `21:0`, `21:10`       |
| Vegetation (`...8fj1u`)  | —                               | `12:4`, `12:6` (dead brambles) + `15:0`, `16:0`–`24:1` (twig / dead-branch bits) |

Only the leafy tree columns (1 & 2 of each tree sheet), the leafy bushes,
and the grass/flower tiles still sway. If a tile is mislabelled, clear its
per-tile Material in the TileSet editor to put it back under the layer's
wind, or assign `static_prop_material.tres` to one that was missed.

## Tree proximity fade — *not* a shader

The "tree goes transparent when the player walks behind it" effect is
CPU-driven by the `Foliage` autoload (`scripts/world/foliage_manager.gd`),
which only evaluates trees near the player and eases `Sprite2D.modulate.a`.
It is deliberately not a shader: the look is a plain uniform alpha fade, and
keeping it on the CPU avoids a per-instance `ShaderMaterial` on every tree.
See `scripts/world/tree.gd`.

**It only works on `TreeProp` nodes, not on trees painted as tileset
tiles.** A `TileMapLayer` is a single `CanvasItem`: you can't give one tile
its own `z_index` (needed for the draw-behind flip) or its own `modulate`
(needed for the fade). So the tree tiles that used to be painted into
`World/TileMap/Vegitation` were converted to `tree.tscn` instances under
`Trees/PaintedTrees` (see `tools/convert_painted_trees.gd`, a one-shot
`EditorScript`). `Foliage` culls by distance, so hundreds of tree nodes are
still cheap.

`tree.gd` is `@tool` and exposes an **Art** group (`art_texture`,
`art_region`, `art_offset`, `swaying`) and a **Trunk Collision** group
(`trunk_enabled`, `trunk_size`, `trunk_offset`) so one `tree.tscn` can stand
in for every tileset tree sprite. A plain instance that sets none of these
behaves exactly as before. The converter fills them in per tree from the
tileset's atlas source / `TileData.texture_origin`; re-run it (on a fresh
checkout) with `ADD_TRUNK_COLLISION = true` if the painted trees should
block movement like the hand-placed ones.
