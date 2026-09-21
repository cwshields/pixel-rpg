#!/usr/bin/env python3
"""Generate a placeholder pixel-art UI kit for Pixel-RPG.

Theme: "Iron & Ember" -- dark stone panels, riveted iron border with a
hard black outline, warm gold/ember accents, top-left bevel light.

    python tools/gen_ui_kit.py

Writes 1x pixel art to assets/UI/kit/ plus a scaled preview. The project
already sets rendering/textures/canvas_textures/default_texture_filter=0,
so these import crisp with no per-file tweak -- just let Godot reimport.
Nine-patch margins are printed on run and listed in README_UIKIT.md.
"""

from __future__ import annotations
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "UI", "kit")
os.makedirs(OUT, exist_ok=True)

# ---- palette ----------------------------------------------------------------
OUTLINE = (13, 12, 20, 255)
FRAME_D = (58, 54, 74, 255)
FRAME_M = (92, 86, 112, 255)
FRAME_L = (140, 132, 164, 255)
PANEL_D = (30, 27, 40, 255)
PANEL_M = (44, 40, 58, 255)
PANEL_L = (55, 50, 72, 255)
SLOT_DK = (20, 18, 28, 255)
RIVET = (232, 197, 106, 255)
RIVET_D = (150, 110, 40, 255)
EMBER = (233, 150, 66, 255)
EMBER_L = (255, 199, 120, 255)
INK = (232, 224, 208, 255)
CLEAR = (0, 0, 0, 0)

HP_FILL = (196, 66, 66, 255)
HP_LIT = (232, 106, 90, 255)
SP_FILL = (110, 176, 74, 255)
SP_LIT = (170, 226, 120, 255)
TRACK = (18, 16, 24, 255)


# ---- primitives -----------------------------------------------------------
def img(w, h, c=CLEAR):
    return Image.new("RGBA", (w, h), c)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((int(x), int(y)), c)


def rect(im, x0, y0, x1, y1, c):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            px(im, x, y, c)


def box(im, x0, y0, x1, y1, c):
    for x in range(int(x0), int(x1) + 1):
        px(im, x, y0, c)
        px(im, x, y1, c)
    for y in range(int(y0), int(y1) + 1):
        px(im, x0, y, c)
        px(im, x1, y, c)


def noise(im, x0, y0, x1, y1, base, lit, dark):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            h = ((x * 73856093) ^ (y * 19349663)) & 0xFFFF
            px(im, x, y, lit if h % 11 == 0 else dark if h % 13 == 0 else base)


def rivet(im, x, y):
    px(im, x, y, RIVET)
    px(im, x + 1, y, RIVET)
    px(im, x, y + 1, RIVET)
    px(im, x + 1, y + 1, RIVET_D)


def stamp(im, ox, oy, rows, cmap):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in cmap:
                px(im, ox + i, oy + j, cmap[ch])


def outline_alpha(im, color=OUTLINE):
    """Trace a 1px outline around every opaque cluster into empty pixels."""
    base = im.copy()
    nb = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1))
    for y in range(im.height):
        for x in range(im.width):
            if base.getpixel((x, y))[3]:
                continue
            for dx, dy in nb:
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height and base.getpixel((nx, ny))[3]:
                    im.putpixel((x, y), color)
                    break


def save(im, name, scale=1):
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(os.path.join(OUT, name))


def render_nine(tile, w, h, m):
    """Stretch a nine-patch tile to w x h, keeping m-px corners intact."""
    tw, th = tile.size
    w, h = max(w, 2 * m + 1), max(h, 2 * m + 1)
    out = img(w, h)
    cs = [(0, m), (m, tw - m), (tw - m, tw)]
    rs = [(0, m), (m, th - m), (th - m, th)]
    cd = [(0, m), (m, w - m), (w - m, w)]
    rd = [(0, m), (m, h - m), (h - m, h)]
    for r in range(3):
        for c in range(3):
            sx0, sx1 = cs[c]
            sy0, sy1 = rs[r]
            dx0, dx1 = cd[c]
            dy0, dy1 = rd[r]
            if sx1 <= sx0 or sy1 <= sy0 or dx1 <= dx0 or dy1 <= dy0:
                continue
            piece = tile.crop((sx0, sy0, sx1, sy1))
            if piece.size != (dx1 - dx0, dy1 - dy0):
                piece = piece.resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
            out.alpha_composite(piece, (dx0, dy0))
    return out


# ---- kit pieces ---------------------------------------------------------
def panel(w=24, h=24, titled=False, title_h=10):
    im = img(w, h)
    rect(im, 0, 0, w - 1, h - 1, FRAME_M)
    box(im, 0, 0, w - 1, h - 1, OUTLINE)
    for x in range(1, w - 1):
        px(im, x, 1, FRAME_L)
        px(im, x, h - 2, FRAME_D)
    for y in range(1, h - 1):
        px(im, 1, y, FRAME_L)
        px(im, w - 2, y, FRAME_D)
    box(im, 3, 3, w - 4, h - 4, OUTLINE)
    noise(im, 4, 4, w - 5, h - 5, PANEL_M, PANEL_L, PANEL_D)
    if titled:
        rect(im, 4, 4, w - 5, 3 + title_h, FRAME_D)
        for x in range(4, w - 4):
            px(im, x, 4, FRAME_M)
        rect(im, 4, 4 + title_h, w - 5, 4 + title_h, OUTLINE)
    for rx, ry in ((2, 2), (w - 4, 2), (2, h - 4), (w - 4, h - 4)):
        rivet(im, rx, ry)
    return im


def slot(w=22, h=22, selected=False):
    im = img(w, h)
    rect(im, 0, 0, w - 1, h - 1, FRAME_M)
    box(im, 0, 0, w - 1, h - 1, OUTLINE)
    for x in range(1, w - 1):  # recessed: dark top/left, light bottom/right
        px(im, x, 1, FRAME_D)
        px(im, x, h - 2, FRAME_L)
    for y in range(1, h - 1):
        px(im, 1, y, FRAME_D)
        px(im, w - 2, y, FRAME_L)
    box(im, 2, 2, w - 3, h - 3, OUTLINE)
    noise(im, 3, 3, w - 4, h - 4, PANEL_D, PANEL_M, SLOT_DK)
    if selected:
        box(im, 0, 0, w - 1, h - 1, EMBER)
        box(im, 1, 1, w - 2, h - 2, EMBER_L)
        box(im, 2, 2, w - 3, h - 3, OUTLINE)
    return im


def bar_under(w=16, h=14):
    im = img(w, h)
    rect(im, 0, 0, w - 1, h - 1, FRAME_M)
    box(im, 0, 0, w - 1, h - 1, OUTLINE)
    for x in range(1, w - 1):
        px(im, x, 1, FRAME_L)
        px(im, x, h - 2, FRAME_D)
    for y in range(1, h - 1):
        px(im, 1, y, FRAME_L)
        px(im, w - 2, y, FRAME_D)
    box(im, 2, 2, w - 3, h - 3, OUTLINE)
    rect(im, 3, 3, w - 4, h - 4, TRACK)
    return im


def bar_fill(w=16, h=14, fill=HP_FILL, lit=HP_LIT):
    im = img(w, h)
    dk = tuple(int(v * 0.62) for v in fill[:3]) + (255,)
    rect(im, 3, 3, w - 4, h - 4, fill)
    for x in range(3, w - 3):
        px(im, x, 3, lit)
        px(im, x, h - 4, dk)
    for y in range(3, h - 3):
        px(im, 3, y, lit)
        px(im, w - 4, y, dk)
    return im


def icon_heart():
    im = img(14, 14)
    rows = [
        " ###   ### ",
        "#+++# #+++#",
        "#+++++++++#",
        "#+++++++++#",
        " #+++++++# ",
        "  #+++++#  ",
        "   #+++#   ",
        "    #+#    ",
        "     #     ",
    ]
    stamp(im, 1, 2, rows, {"#": OUTLINE, "+": HP_FILL})
    for p in ((3, 4), (4, 4), (3, 5)):
        px(im, *p, HP_LIT)
    return im


def icon_bolt():
    im = img(14, 14)
    for i in range(7):  # upper diagonal
        for k in range(3):
            px(im, 9 - i + 1 - k, 1 + i, SP_FILL)
    for i in range(6):  # kink + lower diagonal
        for k in range(3):
            px(im, 11 - i - k, 6 + i, SP_FILL)
    outline_alpha(im)
    for p in ((8, 2), (7, 3), (6, 8)):
        px(im, *p, SP_LIT)
    return im


def divider(w=8, h=4):
    im = img(w, h)
    rect(im, 0, 1, w - 1, h - 2, FRAME_M)
    for x in range(w):
        px(im, x, 0, OUTLINE)
        px(im, x, h - 1, OUTLINE)
    px(im, w // 2 - 1, h // 2 - 1, RIVET)
    px(im, w // 2, h // 2 - 1, RIVET)
    px(im, w // 2 - 1, h // 2, RIVET)
    px(im, w // 2, h // 2, RIVET_D)
    return im


def hotbar_strip(n=8, s=22, gap=2, pad=5, sel=0):
    w = pad * 2 + n * s + (n - 1) * gap
    h = s + 10
    im = render_nine(panel(24, 24), w, h, 6)
    y = (h - s) // 2
    for i in range(n):
        im.alpha_composite(slot(s, s, selected=(i == sel)), (pad + i * (s + gap), y))
    return im


def minimap_round(d=104):
    im = img(d, d)
    cx = cy = (d - 1) / 2
    r_out = d / 2 - 1.5
    r_in = r_out - 8
    up_left = math.radians(225)
    for y in range(d):
        for x in range(d):
            dist = math.hypot(x - cx, y - cy)
            if dist > r_out or dist <= r_in:
                continue
            if dist >= r_out - 1.2 or dist <= r_in + 1.2:
                px(im, x, y, OUTLINE)
            else:
                lit = math.cos(math.atan2(y - cy, x - cx) - up_left)
                px(im, x, y, FRAME_L if lit > 0.4 else FRAME_D if lit < -0.4 else FRAME_M)
    c = int(round(cx))
    for ax, ay in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        rivet(im, int(round(cx + ax * (r_in + 4))) - 1, int(round(cy + ay * (r_in + 4))) - 1)
    rect(im, c - 1, 1, c + 1, 4, RIVET)
    px(im, c, 3, EMBER_L)
    return im


def minimap_square(d=104, b=9):
    im = img(d, d)
    rect(im, 0, 0, d - 1, d - 1, FRAME_M)
    box(im, 0, 0, d - 1, d - 1, OUTLINE)
    for i in range(1, b - 1):
        for x in range(i, d - i):
            px(im, x, i, FRAME_L if i < 3 else FRAME_M)
            px(im, x, d - 1 - i, FRAME_D)
        for y in range(i, d - i):
            px(im, i, y, FRAME_L if i < 3 else FRAME_M)
            px(im, d - 1 - i, y, FRAME_D)
    rect(im, b, b, d - 1 - b, d - 1 - b, CLEAR)
    box(im, b - 1, b - 1, d - b, d - b, OUTLINE)
    box(im, b - 2, b - 2, d - b + 1, d - b + 1, FRAME_D)
    for rx, ry in ((3, 3), (d - 6, 3), (3, d - 6), (d - 6, d - 6)):
        rivet(im, rx, ry)
    return im


# ---- preview ----------------------------------------------------------------
def preview():
    W, H = 340, 190
    im = img(W, H, (22, 20, 30, 255))
    for y in range(0, H, 8):
        for x in range(0, W, 8):
            px(im, x, y, (28, 26, 38, 255))

    # health + stamina, top-left
    im.alpha_composite(icon_heart(), (8, 8))
    hp = render_nine(bar_under(), 120, 14, 4)
    hp.alpha_composite(render_nine(bar_fill(fill=HP_FILL, lit=HP_LIT), int(120 * 0.68), 14, 4), (0, 0))
    im.alpha_composite(hp, (26, 8))
    im.alpha_composite(icon_bolt(), (8, 26))
    sp = render_nine(bar_under(), 120, 14, 4)
    sp.alpha_composite(render_nine(bar_fill(fill=SP_FILL, lit=SP_LIT), int(120 * 0.85), 14, 4), (0, 0))
    im.alpha_composite(sp, (26, 26))

    # minimap, top-right
    im.alpha_composite(minimap_round(), (W - 104 - 8, 8))

    # inventory window, centre
    win = render_nine(panel(32, 32, titled=True), 150, 104, 15)
    gx, gy, gs = 10, 20, 24
    for r in range(3):
        for c in range(5):
            win.alpha_composite(slot(gs, gs), (gx + c * (gs + 2), gy + r * (gs + 2)))
    im.alpha_composite(win, ((W - 150) // 2, 44))

    # hotbar, bottom-centre
    strip = hotbar_strip()
    im.alpha_composite(strip, ((W - strip.width) // 2, H - strip.height - 6))
    return im


# ---- run ------------------------------------------------------------------
PIECES = {
    "panel.png": (panel(24, 24), 6),
    "panel_titled.png": (panel(36, 36, titled=True), "L/R/B 15, top 20"),
    "slot_hotbar.png": (slot(22, 22), 5),
    "slot_hotbar_selected.png": (slot(22, 22, selected=True), 5),
    "slot_inventory.png": (slot(24, 24), 5),
    "bar_under.png": (bar_under(), 4),
    "bar_fill_health.png": (bar_fill(fill=HP_FILL, lit=HP_LIT), 4),
    "bar_fill_stamina.png": (bar_fill(fill=SP_FILL, lit=SP_LIT), 4),
    "icon_heart.png": (icon_heart(), "-"),
    "icon_bolt.png": (icon_bolt(), "-"),
    "divider.png": (divider(), 3),
    "hotbar_strip.png": (hotbar_strip(), "-"),
    "minimap_frame_round.png": (minimap_round(), "-"),
    "minimap_frame_square.png": (minimap_square(), 12),
}

for name, (im, _) in PIECES.items():
    save(im, name)
save(preview(), "preview.png")
save(preview(), "preview_x3.png", scale=3)

lines = ["| file | size | nine-patch margin |", "| --- | --- | --- |"]
for name, (im, m) in PIECES.items():
    lines.append(f"| `{name}` | {im.width}x{im.height} | {m} |")
readme = f"""# Placeholder UI kit -- "Iron & Ember"

Generated by `tools/gen_ui_kit.py`. All 1x pixel art. Re-run the script to
regenerate. `preview_x3.png` shows every piece assembled.

{os.linesep.join(lines)}

## Godot wiring notes

* Import: filter is already off project-wide; just let Godot reimport. Turn
  **Mipmaps** off on each texture, keep **Fix Alpha Border** on.
* **Panels / windows**: `StyleBoxTexture` with `texture` = `panel.png` (or
  `panel_titled.png`), set the four `texture_margin_*` to the margin above,
  `draw_center` on.
* **Health / stamina** (`ProgressBar`): theme override styleboxes ->
  `background` = `bar_under.png`, `fill` = `bar_fill_health.png` /
  `bar_fill_stamina.png`, all as `StyleBoxTexture`, margins 4, and set
  `region_rect`-free full-texture. Put `icon_heart.png` / `icon_bolt.png` in a
  `TextureRect` to the left.
* **Hotbar**: either drop `hotbar_strip.png` in a `TextureRect` as a quick
  mock, or build a real `HBoxContainer` of `TextureButton`/`Panel` nodes each
  using `slot_hotbar.png`, swapping the selected one to
  `slot_hotbar_selected.png`.
* **Inventory**: `panel_titled.png` for the window, `slot_inventory.png` drawn
  per cell via `draw_style_box()` (matches `scripts/ui/inventory_grid.gd`'s
  Tetris-style grid — items can span multiple cells and rotate).
* **Minimap**: `minimap_frame_round.png` / `minimap_frame_square.png` over a
  `SubViewportContainer` or map `TextureRect`; centre is transparent.

Palette: outline `#0d0c14`, iron `#3a364a / #5c5670 / #8c84a4`, panel
`#2c283a`, gold `#e8c56a`, ember `#e99642`, health `#c44242`, stamina `#6eb04a`.
"""
with open(os.path.join(OUT, "README_UIKIT.md"), "w", encoding="utf-8") as fh:
    fh.write(readme)

print("wrote", len(PIECES) + 3, "files to", os.path.relpath(OUT, ROOT))
for name, (im, m) in PIECES.items():
    print(f"  {name:30} {im.width:>3}x{im.height:<3}  margin {m}")
