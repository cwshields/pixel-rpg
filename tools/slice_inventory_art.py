"""Extract inventory UI elements from the PSD source into individual PNGs.

Usage:
    python tools/slice_inventory_art.py

Reads:  C:/development/Pixel-RPG/Assets/inventory-equipment.psd
Writes: assets/UI/inventory/*.png  (native pixel-art resolution)

The PSD is authored at ~2x the 854x480 viewport. Each exported PNG is saved
at the PSD resolution and imported into Godot with nearest-neighbor filtering;
Godot's canvas_items stretch mode handles the viewport scaling automatically.
"""

from __future__ import annotations
import os
from pathlib import Path
from PIL import Image
from psd_tools import PSDImage

PSD_PATH = Path(r"C:\development\Pixel-RPG\Assets\inventory-equipment.psd")
OUT_DIR = Path(r"C:\development\Pixel-RPG\pixel-rpg\assets\UI\inventory")

# The PSD is 1685x954. The game viewport is 854x480 with canvas_items
# stretch mode. We export at half the PSD resolution to land at ~1x viewport
# scale (842x477). Godot's nearest-filter + canvas_items stretch handles the
# final pixel-perfect render.
SCALE = 0.5


def find_layer(root, *names: str):
    """Walk the PSD tree to find a layer by path segments."""
    node = root
    for name in names:
        found = None
        for child in node:
            if child.name == name:
                found = child
                break
        if found is None:
            raise KeyError(f"Layer '{name}' not found under '{getattr(node, 'name', 'root')}'")
        node = found
    return node


def export_layer(layer, filename: str, *, crop: tuple[int, int, int, int] | None = None):
    """Composite a layer (or group) to RGBA, optionally crop, scale, and save."""
    img = layer.composite()
    if img is None:
        print(f"  SKIP {filename} (empty composite)")
        return
    if crop:
        img = img.crop(crop)
    w, h = img.size
    nw, nh = max(1, round(w * SCALE)), max(1, round(h * SCALE))
    img = img.resize((nw, nh), Image.NEAREST)
    path = OUT_DIR / filename
    img.save(path)
    print(f"  {filename}: {nw}x{nh}")


def export_composite_region(psd, filename: str, bbox: tuple[int, int, int, int]):
    """Composite the full PSD, crop a region, scale, and save."""
    full = psd.composite()
    region = full.crop(bbox)
    w, h = region.size
    nw, nh = max(1, round(w * SCALE)), max(1, round(h * SCALE))
    region = region.resize((nw, nh), Image.NEAREST)
    path = OUT_DIR / filename
    region.save(path)
    print(f"  {filename}: {nw}x{nh}")


def main():
    print(f"Reading {PSD_PATH} ...")
    psd = PSDImage.open(str(PSD_PATH))
    print(f"PSD: {psd.width}x{psd.height}")
    os.makedirs(OUT_DIR, exist_ok=True)

    inv = find_layer(psd, "Inventory")

    # --- Full composited panel background (for reference / TextureRect) ---
    print("\nFull panel composites:")
    full = psd.composite()
    fw, fh = full.size
    scaled = full.resize((round(fw * SCALE), round(fh * SCALE)), Image.NEAREST)
    scaled.save(OUT_DIR / "inventory_full.png")
    print(f"  inventory_full.png: {scaled.size[0]}x{scaled.size[1]}")

    # --- Header ---
    print("\nHeader elements:")
    header = find_layer(inv, "Header")
    # Header border (full decorative bar)
    export_layer(find_layer(header, "Header Border"), "header_border.png")
    export_layer(find_layer(header, "Header Bg"), "header_bg.png")
    export_layer(find_layer(header, "Close Btn"), "close_btn.png")
    export_layer(find_layer(header, "Search Btn Border"), "search_border.png")
    export_layer(find_layer(header, "Search Icon"), "search_icon.png")
    export_layer(find_layer(header, "Weight Icon Top-bar"), "weight_icon.png")
    export_layer(find_layer(header, "Coin Item info"), "coin_icon.png")
    # There are two "Inventory Icon" layers — take the larger one (52x56)
    for child in header:
        if child.name == "Inventory Icon" and child.right - child.left > 40:
            export_layer(child, "inventory_icon.png")
            break

    # --- Tab buttons ---
    print("\nTab buttons:")
    tabs = find_layer(inv, "Inventory Section", "Tab Btns")
    tab_names = [
        "Tab All", "Tab Weapons", "Tab Armor", "Tab Potions",
        "Tab Food", "Tab Keys", "Tab Spells", "Tab Materials",
    ]
    for tn in tab_names:
        slug = tn.lower().replace(" ", "_")
        export_layer(find_layer(tabs, tn), f"{slug}.png")

    export_layer(find_layer(tabs, "Selected Border"), "tab_selected_border.png")
    export_layer(find_layer(tabs, "Selected Tab Bg"), "tab_selected_bg.png")

    # Tab icons (the small icons inside each tab)
    icon_names = [
        "All Tab", "Weapons Tab", "Armor Tab", "Potions Tab",
        "Food Tab Icon", "Keys Tab", "Spells Tab", "Materials Tab",
    ]
    for iname in icon_names:
        slug = iname.lower().replace(" ", "_").replace("_icon", "").replace("_tab", "_tab_icon")
        try:
            export_layer(find_layer(tabs, iname), f"{slug}.png")
        except KeyError:
            print(f"  SKIP {slug} (not found)")

    # --- Grid ---
    print("\nGrid elements:")
    grid_group = find_layer(inv, "Inventory Section", "Grid Slots")
    export_layer(find_layer(grid_group, "Inventory Slots Border"), "grid_border.png")
    export_layer(find_layer(grid_group, "Grid Slots"), "grid_slots.png")
    export_layer(find_layer(grid_group, "Tab Bg"), "grid_tab_bg.png")

    # Extract a single grid cell for use as a tile texture
    # Grid Slots is at (528, 214, 1211, 733) in PSD coords, 12x9 cells
    # Cell size = (1211-528)/12 ≈ 56.9, (733-214)/9 ≈ 57.7
    # Grab the top-left cell region
    gs_layer = find_layer(grid_group, "Grid Slots")
    gs_img = gs_layer.composite()
    if gs_img:
        # The grid layer is already positioned; crop relative to its own origin
        gs_w, gs_h = gs_img.size
        cell_w = gs_w / 12
        cell_h = gs_h / 9
        # Grab cell at (1,1) to avoid edge artifacts
        cx, cy = int(cell_w), int(cell_h)
        cell_img = gs_img.crop((cx, cy, cx + int(cell_w), cy + int(cell_h)))
        cw, ch = cell_img.size
        cell_img = cell_img.resize((round(cw * SCALE), round(ch * SCALE)), Image.NEAREST)
        cell_img.save(OUT_DIR / "grid_cell.png")
        print(f"  grid_cell.png: {cell_img.size[0]}x{cell_img.size[1]}")

    # --- Pagination ---
    print("\nPagination:")
    pag = find_layer(inv, "Inventory Section", "Pagination")
    export_layer(find_layer(pag, "Btn Left"), "btn_page_left.png")
    export_layer(find_layer(pag, "Btn Right"), "btn_page_right.png")
    try:
        export_layer(find_layer(pag, "Btn Left-Disabled"), "btn_page_left_disabled.png")
        export_layer(find_layer(pag, "Btn Right-Disabled"), "btn_page_right_disabled.png")
    except KeyError:
        pass

    # --- Hotbar ---
    print("\nHotbar:")
    hotbar = find_layer(inv, "Inventory Section", "Hotbar")
    export_layer(find_layer(hotbar, "Slots"), "hotbar_slots.png")
    export_layer(find_layer(hotbar, "Selected"), "hotbar_selected.png")

    # Extract single hotbar slot
    slots_layer = find_layer(hotbar, "Slots")
    slots_img = slots_layer.composite()
    if slots_img:
        sw = slots_img.size[0]
        slot_w = sw / 8
        single = slots_img.crop((int(slot_w), 0, int(slot_w * 2), slots_img.size[1]))
        sw2, sh2 = single.size
        single = single.resize((round(sw2 * SCALE), round(sh2 * SCALE)), Image.NEAREST)
        single.save(OUT_DIR / "hotbar_slot.png")
        print(f"  hotbar_slot.png: {single.size[0]}x{single.size[1]}")

    # --- Equipment panel ---
    print("\nEquipment panel:")
    equip = find_layer(inv, "Equipment")
    export_layer(find_layer(equip, "Border Bg"), "equip_border.png")
    export_layer(find_layer(equip, "Equipment Bg"), "equip_bg.png")

    # Individual equipment slot borders
    export_layer(find_layer(equip, "Primary Hand"), "equip_primary_hand.png")
    export_layer(find_layer(equip, "Secondary Hand"), "equip_secondary_hand.png")
    export_layer(find_layer(equip, "Gloves"), "equip_gloves.png")
    export_layer(find_layer(equip, "Rune Bonus"), "equip_rune_bonus.png")

    # --- Status panel ---
    print("\nStatus panel:")
    status = find_layer(inv, "Status Section")
    export_layer(find_layer(status, "Status Border"), "status_border.png")
    export_layer(find_layer(status, "Layer 21"), "status_bg.png")
    export_layer(find_layer(status, "Health Bar"), "bar_health.png")
    export_layer(find_layer(status, "Stamina Bar"), "bar_stamina.png")
    export_layer(find_layer(status, "Hunger Bar"), "bar_hunger.png")
    export_layer(find_layer(status, "Mana Bar"), "bar_mana.png")
    export_layer(find_layer(status, "Status Icons"), "status_icons.png")

    # --- Info panel (right column) ---
    print("\nInfo panel:")
    info = find_layer(inv, "Info Panel")
    export_layer(find_layer(info, "Item Details Border"), "info_border.png")
    export_layer(find_layer(info, "Info Panel Bg"), "info_bg.png")

    # Item detail icons
    details = find_layer(info, "Item Details")
    detail_icons = [
        ("DMG Icon", "icon_dmg.png"),
        ("Durability Icon", "icon_durability.png"),
        ("Atk Speed", "icon_atk_speed.png"),
        ("Coin", "icon_coin_detail.png"),
        ("Weight Icon Item-Info", "icon_weight_detail.png"),
        ("Status Decal", "info_decal.png"),
        ("Divider2", "info_divider.png"),
    ]
    for layer_name, fname in detail_icons:
        try:
            export_layer(find_layer(details, layer_name), fname)
        except KeyError:
            print(f"  SKIP {fname} (not found)")

    # Character summary stat icons
    try:
        char_sum = find_layer(info, "Character Summary")
        stat_icons = [
            "Constitution", "Charisma", "Damage", "Defence",
            "Block Chance", "Move Speed", "Atk Speed",
            "Experience Lg", "Level Lg",
            "Fire Resistance", "Cold Resistance", "Lightning Resistance",
            "Venom Resistance", "Phys Resistance", "Arcana Resistance",
            "Fire", "Cold", "Lightning", "Venom", "Dodge Chance", "Arcana Power",
        ]
        for si in stat_icons:
            slug = si.lower().replace(" ", "_")
            try:
                export_layer(find_layer(char_sum, si), f"stat_{slug}.png")
            except KeyError:
                print(f"  SKIP stat_{slug}.png")
    except KeyError:
        print("  SKIP Character Summary group")

    # --- Controls tooltip ---
    print("\nControls tooltip:")
    controls = find_layer(inv, "Controls Tooltip")
    export_layer(find_layer(controls, "Controls Border"), "controls_border.png")
    export_layer(find_layer(controls, "Layer 22"), "controls_bg.png")
    try:
        export_layer(find_layer(controls, "Right-click Icon"), "icon_right_click.png")
    except KeyError:
        pass

    print(f"\nDone. Assets saved to {OUT_DIR}")


if __name__ == "__main__":
    main()
