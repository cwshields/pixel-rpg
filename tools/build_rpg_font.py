# Rebuilds RPG-Font.fnt + RPG-Font_bitmap.png from the RPG-Font.png specimen sheet.
# Usage:  python tools/build_rpg_font.py       (needs Pillow + numpy)
from PIL import Image
import numpy as np, os

ASSET_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'UI')
SRC = os.path.join(ASSET_DIR, 'RPG-Font.png')
SCRATCH = ASSET_DIR  # also drop a copy here (harmless; overwrites the real output)

im = Image.open(SRC).convert('RGBA')
alpha = np.array(im)[:, :, 3]

def trim(x0, y0, x1, y1):
    sub = alpha[y0:y1, x0:x1]
    ys, xs = np.where(sub > 0)
    if len(xs) == 0:
        return None
    return (x0 + xs.min(), y0 + ys.min(), x0 + xs.max() + 1, y0 + ys.max() + 1)

BASE = 8           # baseline row measured from top of the line box
LINE_HEIGHT = 12

# glyph -> dict(src=(x0,y0,x1,y1), yoffset=int, xadvance=int)
G = {}

# ---------- letters (fused capital+lowercase pairs) ----------
band_tops = {1: 1, 2: 12, 3: 23}
band1 = [(1,10),(13,22),(25,34),(37,46),(49,58),(61,70),(73,82),(85,94),(97,104)]
band2 = [(1,9),(12,21),(24,31),(34,47),(50,60),(63,72),(75,84),(87,97),(100,109)]
band3 = [(1,10),(13,22),(25,34),(37,46),(49,62),(65,74),(77,86),(89,98)]
letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
cells = [(c, 1) for c in band1] + [(c, 2) for c in band2] + [(c, 3) for c in band3]
splits = dict(zip(letters, [5,5,5,5,4,5,5,5,4,5,4,4,7,6,5,4,6,5,5,5,5,5,7,5,4,5]))

for ((xs, xe), band), ch in zip(cells, letters):
    top = band_tops[band]
    bot = top + 11
    sp = splits[ch]
    cap = trim(xs, top, xs + sp, bot)
    low = trim(xs + sp, top, xe + 1, bot)
    for c, b in ((ch, cap), (ch.lower(), low)):
        if b is None:
            continue
        G[c] = dict(src=b, yoffset=b[1] - top, xadvance=(b[2] - b[0]) + 1)

# ---------- digits ----------
digit_groups = [(1,5),(8,11),(14,18),(21,25),(28,32),(35,39),(42,46),(49,53),(56,60),(63,67)]
for (xs, xe), d in zip(digit_groups, "0123456789"):
    b = trim(xs, 38, xe + 1, 46)
    G[d] = dict(src=b, yoffset=b[1] - 38, xadvance=(b[2] - b[0]) + 1)

# ---------- punctuation (band 5, baseline ~y59 -> +1 shift) ----------
punct_order = ['.', ',', '!', '?', ':', ';', '/', '\\', '|',
               '(', ')', '[', ']', '"', '&', '_', '-']
punct_x = [(1,3),(6,8),(11,13),(16,19),(22,24),(27,29),(32,36),(39,43),(46,48),
           (51,54),(57,60),(63,66),(69,72),(75,79),(82,86),(89,93),(96,99)]
for c, (xs, xe) in zip(punct_order, punct_x):
    b = trim(xs, 52, xe + 1, 61)
    if b is None:
        continue
    G[c] = dict(src=b, yoffset=(b[1] - 52) + 1, xadvance=(b[2] - b[0]) + 1)

# ---------- dingbat row, part 1: tail of the digit row (same metrics as digits) ----------
# Best-effort identification of hand-drawn ornaments; remap the keys if you disagree.
dingbat_b4 = {'◆': (70, 74),   # filled diamond
              '•': (77, 81),   # centred bullet / separator
              '=':      (84, 88),   # double bar
              '×': (91, 95),   # multiplication cross
              '*':      (98, 102)}  # 4-point star / asterisk
for c, (xs, xe) in dingbat_b4.items():
    b = trim(xs, 38, xe + 1, 46)
    G[c] = dict(src=b, yoffset=b[1] - 38, xadvance=(b[2] - b[0]) + 1)

# ---------- dingbat row, part 2: bottom row (baseline at y=71 -> reference top y=63) ----------
dingbat_b6 = {'«': (1, 8),     # << (left guillemet); swap to '{' if preferred
              '»': (11, 18),   # >> (right guillemet); swap to '}' if preferred
              '<':      (21, 25),
              '>':      (28, 32),
              "'":      (35, 39),   # apostrophe / single quote
              '`':      (42, 46)}   # grave / backtick
for c, (xs, xe) in dingbat_b6.items():
    b = trim(xs, 63, xe + 1, 72)
    G[c] = dict(src=b, yoffset=b[1] - 63, xadvance=(b[2] - b[0]) + 1)

# ---------- pack atlas ----------
GUT = 1
MAXW = 256
items = sorted(G.items())
x = y = GUT
rowh = 0
placed = {}
for c, g in items:
    w = g['src'][2] - g['src'][0]
    h = g['src'][3] - g['src'][1]
    if x + w + GUT > MAXW:
        x = GUT
        y += rowh + GUT
        rowh = 0
    placed[c] = (x, y, w, h)
    x += w + GUT
    rowh = max(rowh, h)
atlas_w = MAXW
atlas_h = y + rowh + GUT
# round up to power-of-two-ish not required; keep tight
atlas = Image.new('RGBA', (atlas_w, atlas_h), (0, 0, 0, 0))
for c, g in items:
    px, py, w, h = placed[c]
    atlas.paste(im.crop(g['src']), (px, py))

atlas_name = 'RPG-Font_bitmap.png'
atlas.save(os.path.join(ASSET_DIR, atlas_name))
atlas.save(os.path.join(SCRATCH, atlas_name))

# ---------- write .fnt (AngelCode text) ----------
lines = []
lines.append('info face="RPG-Font" size=10 bold=0 italic=0 charset="" unicode=1 '
             'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0')
lines.append(f'common lineHeight={LINE_HEIGHT} base={BASE} scaleW={atlas_w} scaleH={atlas_h} '
             'pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0')
lines.append(f'page id=0 file="{atlas_name}"')

chars = []
# space
chars.append(dict(id=32, x=0, y=0, w=0, h=0, xo=0, yo=0, xa=4))
for c, g in items:
    px, py, w, h = placed[c]
    chars.append(dict(id=ord(c), x=px, y=py, w=w, h=h,
                      xo=0, yo=g['yoffset'], xa=g['xadvance']))
lines.append(f'chars count={len(chars)}')
for ch in chars:
    lines.append(
        f'char id={ch["id"]:<3} x={ch["x"]} y={ch["y"]} width={ch["w"]} height={ch["h"]} '
        f'xoffset={ch["xo"]} yoffset={ch["yo"]} xadvance={ch["xa"]} page=0 chnl=15')
lines.append('kernings count=0')

fnt_txt = '\n'.join(lines) + '\n'
open(os.path.join(ASSET_DIR, 'RPG-Font.fnt'), 'w', newline='\n', encoding='ascii').write(fnt_txt)
open(os.path.join(SCRATCH, 'RPG-Font.fnt'), 'w', newline='\n', encoding='ascii').write(fnt_txt)

print(f'atlas {atlas_w}x{atlas_h}, {len(items)} glyphs + space')
print('codepoints:', ' '.join(f'U+{ord(c):04X}' for c, _ in items))
print('wrote:', os.path.join(ASSET_DIR, 'RPG-Font.fnt'))
print('wrote:', os.path.join(ASSET_DIR, atlas_name))
