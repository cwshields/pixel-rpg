# Adds the starter outfit (Pants / Boots / Shirt layers) to the player's
# Slice animations, matching the hand-made outfit on the Walk/Run sheets.
# Clothing only replaces visible *skin* pixels, so outlines, the axe, the
# slash arc and the head are never painted over.
#
# Slice_Down/Side/Up.aseprite share one layer layout (by index):
#   0 legs, 1 torso, 2 axe, 3 arms, 4 slash, 5 head
#   - Shirt: visible torso skin + the first SLEEVE px of each arm from the
#     shoulder (arm pieces that don't touch the torso stay bare).
#   - Pants: legs, with a belt where legs meet the torso (+ buckle on
#     down/side views). Boots: the last BOOT px at the end of each leg.
# The new layers go on top of each .aseprite and are drawn onto the
# matching -Sheet.png. Slice_Run_Side / Slice_Walk_Side are PNG-only: they
# reuse Slice_Side's upper body, so pixels that differ from it are legs.
#
# Refuses to run on files that already have a Pants layer (re-running would
# stack a second outfit); restore the nude sources from git first.
# Usage: python tools/gen_slice_outfit.py [slice_dir]     (needs Pillow, numpy)
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

from aseprite_io import Ase

ROOT = os.path.join(os.path.dirname(__file__), '..')
SLICE_DIR = os.path.join(ROOT, 'assets', 'Entities', 'Characters', 'Body_A', 'Animations', 'Slice_Base')
FRAME = 64
SLEEVE, BOOT = 4, 3

ROLE = {0: 'legs', 1: 'torso', 2: 'axe', 3: 'arms', 4: 'slash', 5: 'head'}
BODY_LAYERS = set(ROLE)
FACING = {'Slice_Down': 'down', 'Slice_Side': 'side', 'Slice_Up': 'up'}
SIDE_VARIANTS = ['Slice_Run_Side', 'Slice_Walk_Side']
CLOTHES = ('Pants', 'Boots', 'Shirt')  # layer order, bottom -> top

# Body skin ramp -> cloth ramp (sampled from the Walk/Run outfit layers).
SKIN_HI, SKIN_MID, SKIN_SH, SKIN_DK = (250, 200, 149), (217, 160, 102), (162, 101, 67), (118, 61, 43)
SKIN = [SKIN_HI, SKIN_MID, SKIN_SH, SKIN_DK]
SHIRT = {SKIN_HI: (172, 153, 106), SKIN_MID: (172, 153, 106), SKIN_SH: (115, 105, 82), SKIN_DK: (82, 78, 61)}
PANTS = {SKIN_HI: (58, 49, 35), SKIN_MID: (47, 39, 28), SKIN_SH: (47, 39, 28), SKIN_DK: (25, 22, 18)}
BOOTS = {SKIN_HI: (90, 57, 28), SKIN_MID: (71, 48, 27), SKIN_SH: (44, 29, 16), SKIN_DK: (44, 29, 16)}
BELT, BUCKLE = (99, 63, 33), (184, 170, 158)

N8 = [(0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)]


def skin_tone(px):
    if px[3] == 0:
        return None
    t = tuple(int(v) for v in px[:3])
    return t if t in SKIN else None


def bfs(mask, seeds):
    """Geodesic (8-connected) distance from seeds, staying inside mask."""
    h, w = mask.shape
    d = np.full((h, w), 10 ** 6, int)
    q = deque()
    for y, x in seeds:
        d[y, x] = 0
        q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in N8:
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and d[ny, nx] > d[y, x] + 1:
                d[ny, nx] = d[y, x] + 1
                q.append((ny, nx))
    return d


def components(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), int)
    n = 0
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not lab[y, x]:
                n += 1
                lab[y, x] = n
                q = deque([(y, x)])
                while q:
                    cy, cx = q.popleft()
                    for dy, dx in N8:
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = n
                            q.append((ny, nx))
    return lab, n


def dilate(mask, r=1):
    out = mask.copy()
    for _ in range(r):
        m = out.copy()
        m[1:] |= out[:-1]; m[:-1] |= out[1:]; m[:, 1:] |= out[:, :-1]; m[:, :-1] |= out[:, 1:]
        out = m
    return out


def make_outfit(comp, owner, masks, facing):
    """comp: HxWx4 visible composite. owner: HxW array naming the role whose
    pixel is visible ('' if none). masks: full per-role layer masks, used for
    geometry. Returns {layer name: HxWx4 image} for CLOTHES."""
    h, w = owner.shape
    out = {k: np.zeros((h, w, 4), np.uint8) for k in CLOTHES}
    tone = np.empty((h, w), object)
    for y in range(h):
        for x in range(w):
            tone[y, x] = skin_tone(comp[y, x])
    is_skin = np.vectorize(lambda t: t is not None)(tone)

    vis_torso, vis_legs, vis_arms = owner == 'torso', owner == 'legs', owner == 'arms'
    torso, legs, arms = masks['torso'], masks['legs'], masks['arms']

    # Shirt: torso, plus sleeves from the shoulder end of arms touching the torso.
    shirt = vis_torso & is_skin
    lab, n = components(arms)
    torso_near = dilate(torso, 2)
    for i in range(1, n + 1):
        m = lab == i
        pts = list(zip(*np.nonzero(m)))
        # The two geodesic extremes of the arm are its shoulder and hand ends.
        d0 = bfs(m, [pts[0]])
        a = max(pts, key=lambda p: d0[p])
        da = bfs(m, [a])
        b = max(pts, key=lambda p: da[p])
        db = bfs(m, [b])
        cands = [p for p in (a, b) if torso_near[p]]
        if not cands:
            continue
        # Both ends near the torso: shoulders sit above hands.
        s = min(cands, key=lambda p: p[0])
        ds = da if s == a else db
        shirt |= m & vis_arms & is_skin & (ds <= SLEEVE)

    # Legs: distance from the hip finds each foot tip; boots sit near the tips.
    hip = legs & dilate(torso, 1)
    seeds = list(zip(*np.nonzero(hip)))
    if not seeds:  # legs not touching the torso: start from their top row
        ys, xs = np.nonzero(legs)
        seeds = [(y, x) for y, x in zip(ys, xs) if y == ys.min()]
    dh = bfs(legs, seeds)
    mx = np.where(legs, dh, -1).max()
    tips = []
    for y, x in zip(*np.nonzero(legs)):
        v = dh[y, x]
        if v < 0.5 * mx:
            continue
        if all(not (0 <= y + dy < h and 0 <= x + dx < w) or not legs[y + dy, x + dx] or dh[y + dy, x + dx] <= v
               for dy, dx in N8):
            tips.append((y, x))
    dt = bfs(legs, tips) if tips else np.full((h, w), 10 ** 6, int)
    boots = vis_legs & is_skin & (dt <= BOOT)
    pants = vis_legs & is_skin & ~boots
    belt = pants & dilate(torso, 1)

    for y, x in zip(*np.nonzero(shirt)):
        out['Shirt'][y, x] = (*SHIRT[tone[y, x]], 255)
    for y, x in zip(*np.nonzero(pants)):
        out['Pants'][y, x] = (*(BELT if belt[y, x] else PANTS[tone[y, x]]), 255)
    if belt.any():
        ys, xs = np.nonzero(belt)
        if facing == 'down':
            cx = int(round(xs.mean()))
            ys_c = [y for y, x in zip(ys, xs) if x == cx]
            if ys_c:
                out['Pants'][ys_c[0], cx] = (*BUCKLE, 255)
        elif facing == 'side':
            i = int(np.argmax(xs))
            out['Pants'][ys[i], xs[i]] = (*BUCKLE, 255)
    for y, x in zip(*np.nonzero(boots)):
        out['Boots'][y, x] = (*BOOTS[tone[y, x]], 255)
    return out


def analyse(a, fi):
    """Per-pixel visible role + full role masks for frame fi."""
    owner = np.full((a.h, a.w), '', object)
    masks = {}
    for li in sorted(ROLE):
        m = a.layer_canvas(fi, li)[..., 3] > 0
        masks[ROLE[li]] = m
        owner[m] = ROLE[li]
    return owner, masks


def draw_over(base, layers):
    out = base.copy()
    for k in CLOTHES:
        m = layers[k][..., 3] > 0
        out[m] = layers[k][m]
    return out


def has_outfit(a):
    return any(L['name'] in CLOTHES for L in a.layers())


def main():
    slice_dir = sys.argv[1] if len(sys.argv) > 1 else SLICE_DIR
    sources = {n: Ase(os.path.join(slice_dir, n + '.aseprite')) for n in FACING}
    dressed = [n for n, a in sources.items() if has_outfit(a)]
    if dressed:
        sys.exit(f'Already has outfit layers: {", ".join(dressed)}. Restore the nude sources from git first.')

    # Side variants are diffed against the *nude* Slice_Side, so do them first.
    side = sources['Slice_Side']
    for n in SIDE_VARIANTS:
        path = os.path.join(slice_dir, n + '-Sheet.png')
        sheet = np.array(Image.open(path).convert('RGBA'))
        for fi in range(len(side.frames)):
            frame = sheet[:, fi * FRAME:(fi + 1) * FRAME].copy()
            frame[frame[..., 3] == 0] = 0
            owner, masks = analyse(side, fi)
            opaque = frame[..., 3] > 0
            diff = np.any(side.composite(fi, BODY_LAYERS) != frame, -1) & opaque
            owner[~opaque] = ''
            owner[diff] = 'legs'
            masks['legs'] = (masks['legs'] & opaque) | diff
            layers = make_outfit(frame, owner, masks, 'side')
            sheet[:, fi * FRAME:(fi + 1) * FRAME] = draw_over(sheet[:, fi * FRAME:(fi + 1) * FRAME], layers)
        Image.fromarray(sheet).save(path)
        print('wrote', n + '-Sheet.png')

    for n, a in sources.items():
        sheet_path = os.path.join(slice_dir, n + '-Sheet.png')
        sheet = np.array(Image.open(sheet_path).convert('RGBA'))
        outfits = []
        for fi in range(len(a.frames)):
            comp = a.composite(fi)
            owner, masks = analyse(a, fi)
            outfits.append(make_outfit(comp, owner, masks, FACING[n]))
        idx = {k: a.add_layer(k) for k in CLOTHES}
        for fi, layers in enumerate(outfits):
            for k, li in idx.items():
                a.set_cel(fi, li, layers[k])
            sheet[:, fi * FRAME:(fi + 1) * FRAME] = draw_over(sheet[:, fi * FRAME:(fi + 1) * FRAME], layers)
        a.save(os.path.join(slice_dir, n + '.aseprite'))
        Image.fromarray(sheet).save(sheet_path)
        print('wrote', n + '.aseprite and', n + '-Sheet.png')


if __name__ == '__main__':
    main()
