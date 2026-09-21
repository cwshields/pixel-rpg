# Using One Image for Multiple Sprite Nodes

Several nodes can share a single imported spritesheet/atlas PNG — each node just
needs to be told which rectangle of that image to draw. Three approaches,
depending on the situation.

## 1. `Sprite2D` region (quickest, per-node)

On each `Sprite2D`:

- `texture` → the shared PNG
- `Region > Enabled` → on
- `Region > Rect` → the x/y/w/h of that sprite's slice

Each node references the same texture resource in memory (Godot dedupes the
import), just with a different rect. Good for a handful of one-offs.

```gdscript
@onready var sheet := preload("res://assets/RPG_Items_Retro_Itchio/Food.png")

func _ready() -> void:
    $Apple.texture = sheet
    $Apple.region_enabled = true
    $Apple.region_rect = Rect2(0, 0, 16, 16)
    $Bread.texture = sheet
    $Bread.region_enabled = true
    $Bread.region_rect = Rect2(16, 0, 16, 16)
```

## 2. `AtlasTexture` resources (reusable, works everywhere)

Make a `.tres` per slice:

- FileSystem → right-click → *Create New > Resource > AtlasTexture*
- `atlas` → the shared PNG, `region` → the slice, save as e.g. `apple.tres`

`apple.tres` is now a normal texture you can drop into a `Sprite2D`,
`TextureRect`, `ItemPickup`, an inventory `Item` resource, a button icon —
anything with a texture slot. Use this when the same slice shows up in
multiple places (e.g. world pickup + HUD icon) — it fits the loot/pickup
system since `ItemPickup` just needs a texture. See loot-pickup-system in
project memory.

Generate them in bulk with a script if the sheet is a regular grid:

```gdscript
const CELL := 16
for i in item_names.size():
    var at := AtlasTexture.new()
    at.atlas = sheet
    at.region = Rect2((i % cols) * CELL, (i / cols) * CELL, CELL, CELL)
    ResourceSaver.save(at, "res://assets/items/%s.tres" % item_names[i])
```

## 3. `hframes` / `vframes` + `frame` (uniform grid, no rects)

If the sheet is an even grid, set `texture` to the sheet, `Hframes`/`Vframes`
to the grid dimensions, then each node just sets an integer `frame` index.
Least fiddly for something like a row of evenly-spaced chest sprites.

## Constraint to keep in mind

Keep every slice on whole-pixel boundaries and at the same 16px density as
the rest of the project, or the atlas'd sprites will shimmer against the tile
grid.
