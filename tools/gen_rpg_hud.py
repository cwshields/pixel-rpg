#!/usr/bin/env python3
"""Generate a native-pixel RPG HUD kit in the "Ornate Bronze" theme
(dark near-black panels, chamfered bronze/gold border, warm accent
line) -- built to resemble a typical AI-mockup RPG status screen, but
as real 1x pixel art you can nine-patch and drop into Godot.

    python tools/gen_rpg_hud.py

Writes to assets/UI/rpg_hud/. Frames/bars/icons ship with NO baked
text -- render "HEALTH", "86/100" etc. with a real Label + a pixel
font (e.g. "Press Start 2P", "m5x7") so values can update at runtime.
preview.png / preview_x2.png bake in placeholder text with a generic
font purely to show the kit assembled -- they aren't meant to be used
as a shipped asset.
"""

from __future__ import annotations
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "UI", "rpg_hud")
os.makedirs(OUT, exist_ok=True)

# ---- palette ----------------------------------------------------------------
BLACK = (5, 4, 5, 255)
BRONZE_D = (43, 33, 22, 255)
BRONZE_M = (86, 67, 43, 255)
BRONZE_L = (150, 118, 74, 255)
GOLD = (201, 166, 94, 255)
GOLD_LIT = (231, 199, 130, 255)
FILL_D = (16, 13, 11, 255)
FILL_M = (24, 20, 16, 255)
FILL_L = (32, 27, 21, 255)
INK = (231, 221, 201, 255)
CLEAR = (0, 0, 0, 0)
SILHOUETTE = (46, 46, 54, 255)
SILHOUETTE_LIT = (64, 64, 74, 255)

HEALTH_FILL, HEALTH_LIT, HEALTH_TRK = (196, 58, 58, 255), (224, 100, 90, 255), (36, 16, 18, 255)
STAMINA_FILL, STAMINA_LIT, STAMINA_TRK = (92, 156, 62, 255), (150, 206, 110, 255), (22, 34, 15, 255)
HUNGER_FILL, HUNGER_LIT, HUNGER_TRK = (207, 143, 52, 255), (230, 182, 100, 255), (36, 26, 12, 255)
MANA_FILL, MANA_LIT, MANA_TRK = (63, 121, 201, 255), (110, 168, 230, 255), (16, 26, 42, 255)


# ---- primitives -----------------------------------------------------------
def img(w, h, c=CLEAR):
    return Image.new("RGBA", (w, h), c)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((int(x), int(y)), c)


def noise(im, x0, y0, x1, y1, base, lit, dark):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            h = ((x * 73856093) ^ (y * 19349663)) & 0xFFFF
            px(im, x, y, lit if h % 11 == 0 else dark if h % 13 == 0 else base)


def stamp(im, ox, oy, rows, cmap):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in cmap:
                px(im, ox + i, oy + j, cmap[ch])


def outline_alpha(im, color=BLACK):
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


def diamond(im, cx, cy, color, outline):
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        px(im, cx + dx, cy + dy, outline)
    px(im, cx, cy, color)


def save(im, name, scale=1):
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(os.path.join(OUT, name))


def render_nine(tile, w, h, m):
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


# ---- ring-mask machinery (chamfered "ornate" frames) ------------------------
def octagon_mask(w, h, chamfer):
    m = Image.new("L", (w, h), 0)
    c = chamfer
    pts = [(c, 0), (w - 1 - c, 0), (w - 1, c), (w - 1, h - 1 - c),
            (w - 1 - c, h - 1), (c, h - 1), (0, h - 1 - c), (0, c)]
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def erode(mask, n):
    m = mask
    for _ in range(n):
        m = m.filter(ImageFilter.MinFilter(3))
    return m


def band(mask, d0, d1):
    return ImageChops.subtract(erode(mask, d0), erode(mask, d1))


def paint(im, mask, color):
    im.paste(Image.new("RGBA", im.size, color), (0, 0), mask)


def paint_noise(im, mask, base, lit, dark):
    layer = img(*im.size)
    noise(layer, 0, 0, im.width - 1, im.height - 1, base, lit, dark)
    im.paste(layer, (0, 0), mask)


def corner_centers(w, h, c):
    o = round(c / 2)
    return [(o, o), (w - 1 - o, o), (o, h - 1 - o), (w - 1 - o, h - 1 - o)]


def ornate_frame(w, h, chamfer=5, title_h=0, corners=True):
    """A chamfered bronze/gold panel: black outline -> bronze -> gold
    hairline -> noisy dark fill, optionally with a title band across
    the top. Nine-patch margin should be >= chamfer + 3."""
    mask = octagon_mask(w, h, chamfer)
    im = img(w, h)
    paint(im, band(mask, 0, 1), BLACK)
    paint(im, band(mask, 1, 2), BRONZE_D)
    paint(im, band(mask, 2, 3), BRONZE_M)
    paint(im, band(mask, 3, 4), BLACK)
    paint(im, band(mask, 4, 5), GOLD)
    fill_mask = erode(mask, 5)
    if title_h > 0:
        rm = Image.new("L", (w, h), 0)
        ImageDraw.Draw(rm).rectangle([5, 5, w - 6, 4 + title_h], fill=255)
        title_mask = ImageChops.multiply(fill_mask, rm)
        body_mask = ImageChops.subtract(fill_mask, title_mask)
        paint(im, title_mask, BRONZE_D)
        dv = Image.new("L", (w, h), 0)
        ImageDraw.Draw(dv).rectangle([5, 5 + title_h, w - 6, 6 + title_h], fill=255)
        paint(im, ImageChops.multiply(fill_mask, dv), BLACK)
        paint_noise(im, body_mask, FILL_M, FILL_L, FILL_D)
    else:
        paint_noise(im, fill_mask, FILL_M, FILL_L, FILL_D)
    if corners:
        for cx, cy in corner_centers(w, h, chamfer):
            diamond(im, cx, cy, GOLD_LIT, BLACK)
    return im


# ---- bars -------------------------------------------------------------------
def bar_under(w=120, h=18, chamfer=3):
    im = ornate_frame(w, h, chamfer=chamfer, corners=False)
    m = round(chamfer / 2) + 3
    rect_mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(rect_mask).rectangle([m, m, w - 1 - m, h - 1 - m], fill=255)
    paint(im, rect_mask, (12, 10, 9, 255))
    return im


def bar_fill(w=120, h=18, chamfer=3, fill=HEALTH_FILL, lit=HEALTH_LIT):
    m = round(chamfer / 2) + 3
    im = img(w, h)
    dk = tuple(int(v * 0.6) for v in fill[:3]) + (255,)
    rm = Image.new("L", (w, h), 0)
    ImageDraw.Draw(rm).rectangle([m, m, w - 1 - m, h - 1 - m], fill=255)
    paint(im, rm, fill)
    top = Image.new("L", (w, h), 0)
    ImageDraw.Draw(top).rectangle([m, m, w - 1 - m, m], fill=255)
    paint(im, top, lit)
    bot = Image.new("L", (w, h), 0)
    ImageDraw.Draw(bot).rectangle([m, h - 1 - m, w - 1 - m, h - 1 - m], fill=255)
    paint(im, bot, dk)
    return im


# ---- stat icons (16x16) ------------------------------------------------------
def icon_health(size=16):
    im = img(size, size)
    rows = [
        " ###   ### ",
        "#+++# #+++#",
        "#+++++++++#",
        "#+++++++++#",
        " #+++++++# ",
        "  #+++++#  ",
        "   #+++#   ",
        "    #+#    ",
    ]
    stamp(im, 1, 3, rows, {"#": BLACK, "+": HEALTH_FILL})
    for p in ((3, 5), (4, 5)):
        px(im, *p, HEALTH_LIT)
    return im


def icon_stamina(size=16):
    im = img(size, size)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 2), (8, size // 2), (2, size - 3), (4, size - 3), (10, size // 2), (4, 2)], fill=STAMINA_FILL)
    d.polygon([(7, 2), (13, size // 2), (7, size - 3), (9, size - 3), (size - 1, size // 2), (9, 2)], fill=STAMINA_FILL)
    outline_alpha(im)
    return im


def icon_hunger(size=16):
    im = img(size, size)
    d = ImageDraw.Draw(im)
    bone = (222, 210, 190, 255)
    d.ellipse([2, 2, 11, 10], fill=HUNGER_FILL)
    d.rectangle([8, 8, 10, 12], fill=bone)
    d.ellipse([7, 11, 12, 14], fill=bone)
    outline_alpha(im)
    px(im, 4, 4, HUNGER_LIT)
    px(im, 5, 3, HUNGER_LIT)
    return im


def icon_mana(size=16):
    im = img(size, size)
    d = ImageDraw.Draw(im)
    d.polygon([(size // 2, 1), (3, 9), (size - 4, 9)], fill=MANA_FILL)
    d.ellipse([3, 6, size - 4, size - 2], fill=MANA_FILL)
    outline_alpha(im)
    px(im, size // 2 - 1, 4, MANA_LIT)
    return im


# ---- action-bar icons (16x16) -----------------------------------------------
def icon_bag(size=16):
    im = img(size, size)
    d = ImageDraw.Draw(im)
    body = (150, 110, 60, 255)
    d.rectangle([3, 6, size - 4, size - 3], fill=body)
    d.polygon([(5, 6), (size - 6, 6), (size - 7, 3), (6, 3)], fill=body)
    outline_alpha(im)
    px(im, size // 2 - 1, 9, (90, 60, 30, 255))
    px(im, size // 2, 9, (90, 60, 30, 255))
    return im


def icon_book(size=16):
    im = img(size, size)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 2, size - 4, size - 3], fill=(120, 70, 40, 255))
    d.line([(size // 2, 3), (size // 2, size - 4)], fill=(70, 40, 20, 255))
    outline_alpha(im)
    return im


def icon_map(size=16):
    im = img(size, size)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 3), (6, 2), (10, 3), (14, 2), (14, 13), (10, 12), (6, 13), (2, 12)], fill=(216, 196, 150, 255))
    outline_alpha(im)
    d.line([(4, 5), (7, 8), (10, 6), (12, 9)], fill=(150, 40, 40, 255))
    return im


def icon_gear(size=16):
    im = img(size, size)
    d = ImageDraw.Draw(im)
    cx = cy = size / 2
    pts = []
    for i in range(8):
        a1 = math.pi * 2 * i / 8
        a2 = a1 + math.pi / 8
        pts.append((cx + 7 * math.cos(a1), cy + 7 * math.sin(a1)))
        pts.append((cx + 4.3 * math.cos(a2), cy + 4.3 * math.sin(a2)))
    d.polygon(pts, fill=(170, 150, 120, 255))
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=BLACK)
    outline_alpha(im)
    return im


def slot(w=32, h=32, chamfer=2):
    """Plain small frame for hotbar/inventory/status-effect cells -- no
    corner tick decoration, just a hairline border."""
    return ornate_frame(w, h, chamfer=chamfer, corners=False)


def slot_selected(w=32, h=32, chamfer=2):
    im = slot(w, h, chamfer)
    ImageDraw.Draw(im).rectangle([1, 1, w - 2, h - 2], outline=GOLD_LIT)
    return im


def frame_button(w=38, h=38, chamfer=4):
    """Bigger frame with corner ticks, for the bottom action-bar buttons."""
    return ornate_frame(w, h, chamfer=chamfer, corners=True)


# ---- portrait -----------------------------------------------------------
def portrait(w=100, h=116, chamfer=8):
    im = ornate_frame(w, h, chamfer=chamfer)
    d = ImageDraw.Draw(im)
    cx = w / 2
    d.ellipse([cx - 20, 20, cx + 20, 60], fill=SILHOUETTE)
    d.polygon([(cx - 30, h - 12), (cx - 22, 55), (cx + 22, 55), (cx + 30, h - 12)], fill=SILHOUETTE)
    d.rectangle([16, h - 16, w - 17, h - 12], fill=SILHOUETTE)
    for x in range(int(cx - 18), int(cx - 8)):
        px(im, x, 24, SILHOUETTE_LIT)
    return im


# ---- radial status wheel ------------------------------------------------
def status_wheel(d=168, r_in=30):
    im = img(d, d)
    cx = cy = (d - 1) / 2
    r_out = d / 2 - 4
    ring = Image.new("L", (d, d), 0)
    ImageDraw.Draw(ring).ellipse([cx - r_out, cy - r_out, cx + r_out, cy + r_out], fill=255)
    hub = Image.new("L", (d, d), 0)
    ImageDraw.Draw(hub).ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], fill=255)
    ring = ImageChops.subtract(ring, hub)
    paint(im, band(ring, 0, 1), BLACK)
    paint(im, band(ring, 1, 3), BRONZE_D)
    paint(im, band(ring, 3, 4), GOLD)
    paint_noise(im, erode(ring, 4), FILL_M, FILL_L, FILL_D)
    dctx = ImageDraw.Draw(im)
    for ang in (45, 135, 225, 315):
        rad = math.radians(ang)
        dctx.line([(cx + r_in * math.cos(rad), cy + r_in * math.sin(rad)),
                    (cx + r_out * math.cos(rad), cy + r_out * math.sin(rad))], fill=BLACK)
    hub_edge = Image.new("L", (d, d), 0)
    ImageDraw.Draw(hub_edge).ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], fill=255)
    paint(im, band(hub_edge, 0, 2), BLACK)
    for ang in (270, 0, 90, 180):
        rad = math.radians(ang)
        x, y = cx + (r_out + 5) * math.cos(rad), cy + (r_out + 5) * math.sin(rad)
        diamond(im, round(x), round(y), GOLD_LIT, BLACK)
    mid_r = (r_in + r_out) / 2 - 2
    icons = {270: icon_health(16), 0: icon_hunger(16), 90: icon_mana(16), 180: icon_stamina(16)}
    for ang, icon in icons.items():
        rad = math.radians(ang)
        x = round(cx + mid_r * math.cos(rad) - icon.width / 2)
        y = round(cy + mid_r * math.sin(rad) - icon.height / 2)
        im.alpha_composite(icon, (x, y))
    return im


# ---- preview (bakes placeholder text; not a shipped asset) ------------------
def _font(size):
    try:
        return ImageFont.truetype(os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", "consola.ttf"), size)
    except Exception:
        return ImageFont.load_default()


def preview():
    W, H = 560, 430
    im = img(W, H, (10, 9, 8, 255))
    f = _font(11)
    fb = _font(12)
    d = ImageDraw.Draw(im)

    def stat_row(x, y, w, icon, label, color, lit, value, maxv):
        under = bar_under(w, 16)
        im.alpha_composite(under, (x + 20, y))
        fill = bar_fill(w, 16, fill=color, lit=lit)
        frac = max(0.0, min(1.0, value / maxv))
        cropped = fill.crop((0, 0, max(6, int(w * frac)), 16))
        im.paste(cropped, (x + 20, y), cropped)
        im.alpha_composite(icon, (x, y))
        d.text((x + 24, y + 1), label, font=f, fill=INK)
        txt = f"{value}/{maxv}"
        d.text((x + 20 + w - 5 - d.textlength(txt, font=f), y + 1), txt, font=f, fill=INK)

    stat_row(10, 10, 150, icon_health(16), "HEALTH", HEALTH_FILL, HEALTH_LIT, 86, 100)
    stat_row(10, 32, 150, icon_stamina(16), "STAMINA", STAMINA_FILL, STAMINA_LIT, 62, 100)
    stat_row(10, 54, 150, icon_hunger(16), "HUNGER", HUNGER_FILL, HUNGER_LIT, 48, 100)
    stat_row(10, 76, 150, icon_mana(16), "MANA", MANA_FILL, MANA_LIT, 72, 100)

    im.alpha_composite(portrait(70, 96), (212, 10))

    status = ornate_frame(150, 170, chamfer=6, title_h=18)
    im.alpha_composite(status, (400, 10))
    d.text((400 + 38, 10 + 4), "STATUS", font=fb, fill=INK)
    labels = [("HEALTH", HEALTH_FILL, "86/100"), ("STAMINA", STAMINA_FILL, "62/100"),
              ("HUNGER", HUNGER_FILL, "48/100"), ("MANA", MANA_FILL, "72/100")]
    for i, (name, color, val) in enumerate(labels):
        yy = 10 + 30 + i * 18
        d.text((400 + 12, yy), name, font=f, fill=color)
        d.text((400 + 150 - 8 - d.textlength(val, font=f), yy), val, font=f, fill=INK)

    hb_slot = slot()
    hb_sel = slot_selected()
    icons8 = [icon_health(16), icon_stamina(16), icon_hunger(16), icon_mana(16),
              icon_bag(16), icon_book(16), icon_map(16), icon_gear(16)]
    for i in range(8):
        sx = 10 + i * 38
        im.alpha_composite(hb_sel if i == 0 else hb_slot, (sx, 116))
        im.alpha_composite(icons8[i], (sx + 8, 124))
        d.text((sx + 2, 118), str(i + 1), font=f, fill=GOLD)

    fx_panel = ornate_frame(300, 88, chamfer=6, title_h=16)
    im.alpha_composite(fx_panel, (10, 166))
    d.text((10 + 10, 166 + 3), "STATUS EFFECTS", font=f, fill=GOLD)
    fxs = [icon_health(16), icon_mana(16), icon_stamina(16)]
    for i, fx in enumerate(fxs):
        fxs_x = 10 + 12 + i * 36
        im.alpha_composite(slot(), (fxs_x, 190))
        im.alpha_composite(fx, (fxs_x + 8, 198))

    quest = ornate_frame(150, 110, chamfer=6, title_h=16)
    im.alpha_composite(quest, (400, 190))
    d.text((400 + 12, 190 + 3), "QUEST", font=f, fill=GOLD)
    d.text((400 + 12, 190 + 24), "The Lost", font=f, fill=HUNGER_FILL)
    d.text((400 + 12, 190 + 38), "Watchtower", font=f, fill=HUNGER_FILL)

    wheel = status_wheel(180, 30)
    im.alpha_composite(wheel, ((W - 180) // 2, 264))

    btn = frame_button()
    action_icons = [icon_bag(16), icon_book(16), icon_map(16), icon_gear(16)]
    for i, ic in enumerate(action_icons):
        bx = 400 + i * 42
        by = 380
        im.alpha_composite(btn, (bx, by))
        im.alpha_composite(ic, (bx + 11, by + 11))

    return im


# ---- run --------------------------------------------------------------------
save(ornate_frame(44, 44, chamfer=6), "panel.png")
save(ornate_frame(44, 60, chamfer=6, title_h=16), "panel_titled.png")
save(slot(), "slot.png")
save(slot_selected(), "slot_selected.png")
save(frame_button(), "frame_button.png")
save(bar_under(), "bar_under.png")
save(bar_fill(fill=HEALTH_FILL, lit=HEALTH_LIT), "bar_fill_health.png")
save(bar_fill(fill=STAMINA_FILL, lit=STAMINA_LIT), "bar_fill_stamina.png")
save(bar_fill(fill=HUNGER_FILL, lit=HUNGER_LIT), "bar_fill_hunger.png")
save(bar_fill(fill=MANA_FILL, lit=MANA_LIT), "bar_fill_mana.png")
save(icon_health(), "icon_health.png")
save(icon_stamina(), "icon_stamina.png")
save(icon_hunger(), "icon_hunger.png")
save(icon_mana(), "icon_mana.png")
save(icon_bag(), "icon_bag.png")
save(icon_book(), "icon_book.png")
save(icon_map(), "icon_map.png")
save(icon_gear(), "icon_gear.png")
save(portrait(), "portrait_placeholder.png")
save(status_wheel(), "wheel_status.png")
save(preview(), "preview.png")
save(preview(), "preview_x2.png", scale=2)

readme = """# Native-pixel RPG HUD kit -- "Ornate Bronze"

Generated by `tools/gen_rpg_hud.py` (re-run to regenerate). All 1x pixel
art, no anti-aliasing, no baked text on the shipped pieces.

| file | size | nine-patch margin |
| --- | --- | --- |
| `panel.png` | 44x44 | 8 |
| `panel_titled.png` | 44x60 | sides/bottom 8, top 26 (title band 16px + divider) |
| `slot.png` / `slot_selected.png` | 32x32 | 5 (plain hairline, no corner ticks -- hotbar/inventory/status-effect cells) |
| `frame_button.png` | 38x38 | 7 (corner-tick frame -- bottom action-bar buttons) |
| `bar_under.png` | 120x18 | 6 |
| `bar_fill_health/stamina/hunger/mana.png` | 120x18 | 6 (crop-to-fraction, don't 9-slice-stretch the fill) |
| `icon_health/stamina/hunger/mana.png` | 16x16 | - |
| `icon_bag/book/map/gear.png` | 16x16 | - |
| `portrait_placeholder.png` | 100x116 | fixed size, not a nine-patch |
| `wheel_status.png` | 168x168 | fixed size, not a nine-patch |

`preview.png` / `preview_x2.png` show the whole kit assembled roughly
like the reference mockup -- including baked-in labels/numbers for
illustration only. Don't ship those two; build the real layout from
the pieces above plus Godot `Label`s.

## Wiring notes

* Import with mipmaps off (project's texture filter is already nearest).
* Panels/slots: `StyleBoxTexture`, `texture_margin_*` = the margin above,
  `draw_center` on.
* **Bars**: `bar_under.png` as the `ProgressBar` `background` stylebox.
  For the fill, either use `bar_fill_*.png` as the `fill` stylebox (it
  will stretch, which is fine since it's a flat colour), or crop it to
  `value/max` width yourself for a harder pixel edge like the preview.
* **Text**: none of these bake in labels or numbers -- add `Label`
  nodes with a real pixel font (e.g. "Press Start 2P" or "m5x7", both
  free) so HEALTH/86/100/etc. can actually update.
* **Hotbar/inventory**: `slot.png` / `slot_selected.png` at whatever
  size you want (they're nine-patch); this replaces/matches
  `assets/UI/kit/slot_hotbar*.png` from the earlier "Iron & Ember" kit
  if you want to move the hotbar over to this theme instead.
* **Portrait**: `portrait_placeholder.png` is a single baked image
  (frame + silhouette) -- swap in a real character portrait later, or
  keep the frame and replace only the silhouette.
* **Status wheel**: `wheel_status.png` is fully baked (ring + quadrant
  icons); drop it in a `TextureRect` where you want the compact status
  readout.

Palette: outline `#050405`, bronze `#2b2116 / #56432b / #96764a`, gold
`#c9a65e`, fill `#181410`, health `#c43a3a`, stamina `#5c9c3e`, hunger
`#cf8f34`, mana `#3f79c9`.
"""
with open(os.path.join(OUT, "README_RPG_HUD.md"), "w", encoding="utf-8") as fh:
    fh.write(readme)

print("wrote RPG HUD kit to", os.path.relpath(OUT, ROOT))
