"""
Builds SpriteFrames .tres resources for all enemies in assets/Enemies/.

Each enemy has sprite sheets for Idle, Run, Death, and optionally Hit.
Two art-pack styles exist:
  - "Old style" (Skeleton/Orc Crews): Idle sheets are 128x32 (4 frames of 32x32),
    Run/Death sheets vary, frame width always 64.
  - "New style" (everything else): all sheets use 64x64 frames.

Frame heights may be shorter than 64 — a margin pads the frame to a consistent
64-pixel logical height so sprites align at their feet.

Usage:  python tools/build_enemy_sprite_frames.py
"""
from __future__ import annotations
from PIL import Image
import os
import re
from typing import Optional

ROOT = os.path.join(os.path.dirname(__file__), "..")
ENEMIES_DIR = os.path.join(ROOT, "assets", "Enemies")
OUT_DIR = os.path.join(ROOT, "resources", "characters", "enemies")

ANIM_SPEEDS = {
    "idle": (True, 6.0),
    "walk": (True, 10.0),
    "hit": (False, 10.0),
    "death": (False, 8.0),
}


def find_sheet(variant_dir: str, anim_name: str) -> Optional[str]:
    """Find a *-Sheet.png for the given animation name under variant_dir."""
    for dirpath, _dirs, files in os.walk(variant_dir):
        dirname = os.path.basename(dirpath).lower()
        if dirname == anim_name.lower() or dirname == "hit" and anim_name == "hit":
            for f in files:
                if f.lower().endswith("-sheet.png"):
                    return os.path.join(dirpath, f)
    return None


def sheet_info(path: str) -> tuple[int, int, int]:
    """Returns (frame_width, frame_height, num_frames) for a sheet."""
    with Image.open(path) as im:
        w, h = im.size
    if w == 128 and h == 32:
        return 32, 32, 4
    frame_w = 64
    num = w // frame_w
    return frame_w, h, num


def to_godot_path(abs_path: str) -> str:
    rel = os.path.relpath(abs_path, ROOT).replace("\\", "/")
    return f"res://{rel}"


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def build_tres(variant_name: str, sheets: dict[str, str]) -> str:
    """Build a SpriteFrames .tres string for one enemy variant."""
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]

    tex_ids = {}
    anim_order = ["idle", "walk", "hit", "death"]
    present = [a for a in anim_order if a in sheets]

    for i, anim in enumerate(present, 1):
        tid = f"tex_{i}"
        tex_ids[anim] = tid
        gpath = to_godot_path(sheets[anim])
        lines.append(f'[ext_resource type="Texture2D" path="{gpath}" id="{tid}"]')
    lines.append("")

    frame_counter = 1
    frame_map: dict[str, list[str]] = {}

    for anim in present:
        fw, fh, nf = sheet_info(sheets[anim])
        ids = []
        for col in range(nf):
            fid = f"frame_{frame_counter}"
            frame_counter += 1
            ids.append(fid)
            lines.append(f'[sub_resource type="AtlasTexture" id="{fid}"]')
            lines.append(f'atlas = ExtResource("{tex_ids[anim]}")')
            lines.append(f"region = Rect2({col * fw}, 0, {fw}, {fh})")
            if fh < 64:
                lines.append(f"margin = Rect2(0, 0, 0, {64 - fh})")
            lines.append("")
        frame_map[anim] = ids

    lines.append("[resource]")
    entries = []
    for anim in present:
        loop, speed = ANIM_SPEEDS[anim]
        ids = frame_map[anim]
        frame_blocks = []
        for fid in ids:
            frame_blocks.append(
                '{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % fid
            )
        godot_name = anim
        entry = (
            '"frames": [%s],\n"loop": %d,\n"name": &"%s",\n"speed": %.1f'
            % (", ".join(frame_blocks), 1 if loop else 0, godot_name, speed)
        )
        entries.append(entry)

    lines.append("animations = [{")
    lines.append("\n}, {\n".join(entries))
    lines.append("}]")
    lines.append("")
    return "\n".join(lines)


def discover_enemies() -> list[tuple[str, str, dict[str, str]]]:
    """Walk assets/Enemies/ and discover all enemy variants with their sheets.

    Returns list of (slug, display_name, {anim: sheet_path}).
    Prefixes biome name when multiple biomes produce the same slug.
    """
    raw = []
    for biome in sorted(os.listdir(ENEMIES_DIR)):
        biome_path = os.path.join(ENEMIES_DIR, biome)
        if not os.path.isdir(biome_path):
            continue

        for entry in sorted(os.listdir(biome_path)):
            entry_path = os.path.join(biome_path, entry)
            if not os.path.isdir(entry_path):
                continue

            contents = os.listdir(entry_path)
            has_anim_content = any(
                (os.path.isdir(os.path.join(entry_path, d)) and d.lower() in ("idle", "run", "death", "hit"))
                or (os.path.isfile(os.path.join(entry_path, d)) and d.lower().endswith("-sheet.png"))
                for d in contents
            )

            if has_anim_content:
                sheets = _find_sheets(entry_path)
                if sheets:
                    base_slug = slugify(entry)
                    raw.append((biome, base_slug, f"{biome}/{entry}", sheets))
            else:
                for variant in sorted(os.listdir(entry_path)):
                    variant_path = os.path.join(entry_path, variant)
                    if not os.path.isdir(variant_path):
                        continue
                    sheets = _find_sheets(variant_path)
                    if sheets:
                        base_slug = slugify(variant)
                        raw.append(
                            (biome, base_slug, f"{biome}/{entry}/{variant}", sheets)
                        )

    # Detect slug collisions and prefix with biome
    from collections import Counter
    slug_counts = Counter(slug for _, slug, _, _ in raw)
    results = []
    for biome, base_slug, display, sheets in raw:
        if slug_counts[base_slug] > 1:
            slug = slugify(biome) + "_" + base_slug
        else:
            slug = base_slug
        results.append((slug, display, sheets))
    return results


def _find_sheets(variant_dir: str) -> dict[str, str]:
    """Find animation sheets in a variant directory.

    Handles two layouts:
      1. variant/Idle/Idle-Sheet.png  (animation in a subdirectory)
      2. variant/Idle-Sheet.png       (animation sheet directly in folder)
    """
    sheets = {}
    anim_map = {"idle": "idle", "run": "walk", "death": "death", "hit": "hit"}

    for item in os.listdir(variant_dir):
        item_path = os.path.join(variant_dir, item)
        item_lower = item.lower()

        if os.path.isdir(item_path) and item_lower in anim_map:
            for f in os.listdir(item_path):
                if f.lower().endswith("-sheet.png"):
                    sheets[anim_map[item_lower]] = os.path.join(item_path, f)
                    break
        elif os.path.isfile(item_path) and item_lower.endswith("-sheet.png"):
            for anim_key in anim_map:
                if item_lower.startswith(anim_key):
                    sheets[anim_map[anim_key]] = item_path
                    break
    return sheets


SKIP = {"skeleton_warrior"}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    enemies = discover_enemies()
    written = 0
    for slug, display, sheets in enemies:
        if slug in SKIP:
            print(f"  skip {display} (already hand-tuned)")
            continue
        content = build_tres(display, sheets)
        out_path = os.path.join(OUT_DIR, f"{slug}_sprite_frames.tres")
        with open(out_path, "w", newline="\n") as f:
            f.write(content)
        print(f"wrote {slug}_sprite_frames.tres  ({display})")
        written += 1
    print(f"\n{written} sprite frames written to {OUT_DIR}")


if __name__ == "__main__":
    main()
