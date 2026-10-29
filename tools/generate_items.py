#!/usr/bin/env python3
"""Batch-generate Godot 4 .tres item resource files from a JSON catalog.

Usage:  python tools/generate_items.py [--catalog tools/item_catalog.json]
                                       [--outdir resources/items]
                                       [--dry-run]

Each catalog entry describes one base item: its sprite sheet, atlas region,
item class (Weapon, Armor, Shield, Ring, etc.), stats, and metadata.
The script emits one .tres file per entry, ready for Godot to import.

UIDs are omitted — Godot auto-assigns them on first project scan.
"""

import argparse
import json
import os
import sys
import hashlib

# ---------------------------------------------------------------------------
# Script <-> class_name mapping
# ---------------------------------------------------------------------------
SCRIPT_PATHS = {
    "Weapon":           "res://scripts/items/weapon.gd",
    "Armor":            "res://scripts/items/armor.gd",
    "Shield":           "res://scripts/items/shield.gd",
    "Ring":             "res://scripts/items/ring.gd",
    "Amulet":           "res://scripts/items/amulet.gd",
    "Consumable":       "res://scripts/items/consumable.gd",
    "Tool":             "res://scripts/items/tool.gd",
    "CraftingMaterial": "res://scripts/items/crafting_material.gd",
    "RuneStone":        "res://scripts/items/rune_stone.gd",
}

CATEGORY_INT = {
    "WEAPON": 0, "ARMOR": 1, "TOOL": 2, "RING": 3, "AMULET": 4,
    "CONSUMABLE": 5, "MATERIAL": 6, "QUEST": 7, "RUNE_STONE": 8,
}

RARITY_INT = {
    "COMMON": 0, "MAGIC": 1, "RARE": 2, "SET": 3, "UNIQUE": 4,
}

CLASS_AFFINITY_INT = {
    "NONE": 0, "WARRIOR": 1, "RANGER": 2, "SORCERER": 3,
}

WEAPON_TYPE_INT = {
    "SWORD": 0, "DAGGER": 1, "AXE": 2, "SPEAR": 3,
    "BOW": 4, "STAFF": 5, "MACE": 6,
}

ARMOR_SLOT_INT = {
    "HEAD": 0, "CHEST": 1, "FEET": 2, "GAUNTLETS": 3,
}

CONSUMABLE_TYPE_INT = {
    "POTION": 0, "FOOD": 1, "SCROLL": 2, "ELIXIR": 3,
}

TOOL_TYPE_INT = {
    "PICKAXE": 0, "AXE": 1, "FISHING_ROD": 2, "HOE": 3, "SHOVEL": 4, "SCYTHE": 5,
}


def make_id(s: str) -> str:
    """Deterministic short ID for ext/sub resources."""
    return hashlib.md5(s.encode()).hexdigest()[:5]


def build_tres(entry: dict) -> str:
    """Build the full .tres text for one catalog entry."""
    item_class = entry["class"]
    script_path = SCRIPT_PATHS[item_class]
    sprite_sheet = entry["sprite_sheet"]
    region = entry["region"]  # [x, y, w, h]

    script_id = make_id("script_" + script_path)
    texture_id = make_id("tex_" + sprite_sheet)
    atlas_id = make_id("atlas_" + entry["id"])

    lines = []

    # Header
    lines.append(f'[gd_resource type="Resource" script_class="{item_class}" format=3]')
    lines.append("")

    # External resources
    lines.append(f'[ext_resource type="Script" path="{script_path}" id="{script_id}"]')
    lines.append(f'[ext_resource type="Texture2D" path="{sprite_sheet}" id="{texture_id}"]')
    lines.append("")

    # Atlas sub-resource
    lines.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_{atlas_id}"]')
    lines.append(f'atlas = ExtResource("{texture_id}")')
    lines.append(f'region = Rect2({region[0]}, {region[1]}, {region[2]}, {region[3]})')
    lines.append("")

    # Resource block
    lines.append("[resource]")
    lines.append(f'script = ExtResource("{script_id}")')

    # Class-specific fields
    if item_class == "Weapon":
        lines.append(f'weapon_type = {WEAPON_TYPE_INT[entry.get("weapon_type", "SWORD")]}')
        if entry.get("damage"):
            lines.append(f'damage = {float(entry["damage"])}')
        if entry.get("attack_speed"):
            lines.append(f'attack_speed = {float(entry["attack_speed"])}')
        if entry.get("crit_bonus"):
            lines.append(f'crit_bonus = {float(entry["crit_bonus"])}')
        if entry.get("two_handed"):
            lines.append(f'two_handed = true')
        if entry.get("min_damage"):
            lines.append(f'min_damage = {float(entry["min_damage"])}')
        if entry.get("max_damage"):
            lines.append(f'max_damage = {float(entry["max_damage"])}')
        if entry.get("max_durability"):
            lines.append(f'max_durability = {int(entry["max_durability"])}')
        if entry.get("reach_scale") and entry["reach_scale"] != 1.0:
            lines.append(f'reach_scale = {float(entry["reach_scale"])}')

    elif item_class == "Armor":
        lines.append(f'armor_slot = {ARMOR_SLOT_INT[entry.get("armor_slot", "CHEST")]}')
        if entry.get("defense"):
            lines.append(f'defense = {float(entry["defense"])}')

    elif item_class == "Shield":
        if entry.get("defense"):
            lines.append(f'defense = {float(entry["defense"])}')
        if entry.get("block_chance"):
            lines.append(f'block_chance = {float(entry["block_chance"])}')

    elif item_class == "Ring" or item_class == "Amulet":
        mods = entry.get("stat_modifiers", {})
        if mods:
            lines.append("stat_modifiers = {")
            for k, v in mods.items():
                lines.append(f'"{k}": {float(v)},')
            lines.append("}")

    elif item_class == "Consumable":
        lines.append(f'consumable_type = {CONSUMABLE_TYPE_INT[entry.get("consumable_type", "POTION")]}')
        if entry.get("heal_amount"):
            lines.append(f'heal_amount = {float(entry["heal_amount"])}')
        if entry.get("stamina_amount"):
            lines.append(f'stamina_amount = {float(entry["stamina_amount"])}')
        if entry.get("buff_stat"):
            lines.append(f'buff_stat = &"{entry["buff_stat"]}"')
            lines.append(f'buff_amount = {float(entry.get("buff_amount", 0))}')
            lines.append(f'buff_duration = {float(entry.get("buff_duration", 0))}')

    elif item_class == "Tool":
        lines.append(f'tool_type = {TOOL_TYPE_INT[entry.get("tool_type", "PICKAXE")]}')
        if entry.get("power"):
            lines.append(f'power = {int(entry["power"])}')
        if entry.get("max_durability"):
            lines.append(f'max_durability = {int(entry["max_durability"])}')

    # Common ItemBase fields
    lines.append(f'id = &"{entry["id"]}"')
    lines.append(f'display_name = "{entry["display_name"]}"')
    if entry.get("description"):
        lines.append(f'description = "{entry["description"]}"')
    lines.append(f'icon = SubResource("AtlasTexture_{atlas_id}")')

    if entry.get("max_stack") and entry["max_stack"] != 1:
        lines.append(f'max_stack = {int(entry["max_stack"])}')
    if entry.get("value"):
        lines.append(f'value = {int(entry["value"])}')

    cat = entry.get("category")
    if cat:
        lines.append(f'category = {CATEGORY_INT[cat]}')

    rarity = entry.get("rarity", "COMMON")
    if rarity != "COMMON":
        lines.append(f'rarity = {RARITY_INT[rarity]}')

    affinity = entry.get("class_affinity", "NONE")
    if affinity != "NONE":
        lines.append(f'class_affinity = {CLASS_AFFINITY_INT[affinity]}')

    if entry.get("weight"):
        lines.append(f'weight = {float(entry["weight"])}')

    # Requirements
    if entry.get("required_level"):
        lines.append(f'required_level = {int(entry["required_level"])}')
    if entry.get("required_strength"):
        lines.append(f'required_strength = {int(entry["required_strength"])}')
    if entry.get("required_dexterity"):
        lines.append(f'required_dexterity = {int(entry["required_dexterity"])}')

    # Shape
    if entry.get("shape"):
        shape = entry["shape"]
        shape_str = ", ".join(f'"{s}"' for s in shape)
        lines.append(f'shape = PackedStringArray({shape_str})')

    lines.append("")  # trailing newline
    return "\n".join(lines)


def output_path(outdir: str, entry: dict) -> str:
    """Determine the output .tres file path from the entry."""
    item_class = entry["class"]
    subdir = entry.get("subdir")
    if not subdir:
        subdir = {
            "Weapon": "weapons",
            "Armor": "armor",
            "Shield": "shields",
            "Ring": "rings",
            "Amulet": "amulets",
            "Consumable": "consumables",
            "Tool": "tools",
            "CraftingMaterial": "materials",
            "RuneStone": "rune_stones",
        }.get(item_class, "misc")

        # Sub-subdirectory for armor slots
        if item_class == "Armor":
            slot = entry.get("armor_slot", "CHEST").lower()
            subdir = f"armor/{slot}"

    return os.path.join(outdir, subdir, f'{entry["id"]}.tres')


def main():
    parser = argparse.ArgumentParser(description="Generate .tres item files from catalog")
    parser.add_argument("--catalog", default="tools/item_catalog.json")
    parser.add_argument("--outdir", default="resources/items")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    # Support both single file and directory of JSON files
    catalog_path = args.catalog
    entries = []
    if os.path.isdir(catalog_path):
        for f in sorted(os.listdir(catalog_path)):
            if f.endswith(".json"):
                with open(os.path.join(catalog_path, f)) as fh:
                    data = json.load(fh)
                    if isinstance(data, list):
                        entries.extend(data)
                    elif isinstance(data, dict) and "items" in data:
                        entries.extend(data["items"])
    else:
        with open(catalog_path) as fh:
            data = json.load(fh)
            if isinstance(data, list):
                entries = data
            elif isinstance(data, dict) and "items" in data:
                entries = data["items"]

    print(f"Loaded {len(entries)} catalog entries")

    created = 0
    skipped = 0
    for entry in entries:
        path = output_path(args.outdir, entry)
        tres = build_tres(entry)

        if args.dry_run:
            print(f"  [DRY] {path}")
            created += 1
            continue

        os.makedirs(os.path.dirname(path), exist_ok=True)

        # Skip if file already exists (don't overwrite hand-edited items)
        if os.path.exists(path):
            skipped += 1
            continue

        with open(path, "w", newline="\n") as f:
            f.write(tres)
        created += 1

    print(f"Created: {created}, Skipped (existing): {skipped}")


if __name__ == "__main__":
    main()
