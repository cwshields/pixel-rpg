# Builds SpriteFrames .tres resources for the animals-pack critters from
# their PNG sheets (assets/Entities/animals-pack/PNG/Without_shadow). Each
# sheet is a 32x32 grid, 4 rows (down/up/left/right) x N frame columns;
# we only keep down/up/right (mirrored to "side" via AnimatedSprite2D
# flip_h, same convention as the player and enemy art).
# Usage: python tools/build_critter_sprite_frames.py     (needs Pillow)
from PIL import Image
import os

ROOT = os.path.join(os.path.dirname(__file__), '..')
SHEET_DIR = os.path.join(ROOT, 'assets', 'Entities', 'animals-pack', 'PNG', 'Without_shadow')
OUT_DIR = os.path.join(ROOT, 'resources', 'characters', 'animals')
FRAME = 32
ROW_DOWN, ROW_UP, ROW_LEFT, ROW_RIGHT = 0, 1, 2, 3

# name -> {base_anim_name: sheet_filename}. "flee" is each animal's run
# (or, for the grouse, flight) animation.
CRITTERS = {
    'Boar': {
        'idle': 'Boar_Idle.png', 'walk': 'Boar_Walk.png', 'flee': 'Boar_Run.png',
        'hurt': 'Boar_Hurt.png', 'death': 'Boar_Death.png', 'attack': 'Boar_Attack.png',
    },
    'Deer': {
        'idle': 'Deer_Idle.png', 'walk': 'Deer_Walk.png', 'flee': 'Deer_Run.png',
        'hurt': 'Deer_Hurt.png', 'death': 'Deer_Death.png',
    },
    'Fox': {
        'idle': 'Fox_Idle.png', 'walk': 'Fox_walk.png', 'flee': 'Fox_Run.png',
        'hurt': 'Fox_Hurt.png', 'death': 'Fox_Death.png',
    },
    'Hare': {
        'idle': 'Hare_Idle.png', 'walk': 'Hare_Walk.png', 'flee': 'Hare_Run.png',
        'hurt': 'Hare_Hurt.png', 'death': 'Hare_Death.png',
    },
    'Black_grouse': {
        'idle': 'Black_grouse_Idle.png', 'walk': 'Black_grouse_Walk.png', 'flee': 'Black_grouse_Flight.png',
        'hurt': 'Black_grouse_Hurt.png', 'death': 'Black_grouse_Death.png',
    },
}

# base_anim_name -> (loop, speed)
ANIM_PARAMS = {
    'idle': (True, 6.0),
    'walk': (True, 8.0),
    'flee': (True, 12.0),
    'hurt': (False, 10.0),
    'death': (False, 8.0),
    'attack': (False, 10.0),
}

DIRECTIONS = [('down', ROW_DOWN), ('up', ROW_UP), ('side', ROW_RIGHT)]

# (animal, anim) -> row to use for "side" instead of the ROW_RIGHT default.
# Fox_Run.png ships with its left/right rows swapped relative to every other
# sheet in the pack (verified by eye: row 2 is right-facing, row 3 is
# left-facing there, backwards from Fox_Idle/Fox_walk and every other
# critter's sheets) — flip_h then mirrored an already-left-facing frame,
# making the fox face right while fleeing left and vice versa.
SIDE_ROW_OVERRIDES = {
    ('Fox', 'flee'): ROW_LEFT,
}


def cols_for(path: str) -> int:
    with Image.open(path) as im:
        return im.width // FRAME


def build(animal: str, sheets: dict) -> str:
    lines = ['[gd_resource type="SpriteFrames" format=3]', '']
    tex_id = {}
    for anim, filename in sheets.items():
        rel = f"res://assets/Entities/animals-pack/PNG/Without_shadow/{animal}/{filename}"
        tid = f"tex_{anim}"
        tex_id[anim] = tid
        lines.append(f'[ext_resource type="Texture2D" path="{rel}" id="{tid}"]')
    lines.append('')

    frame_ids = {}  # (anim, direction) -> [sub_resource ids]
    for anim, filename in sheets.items():
        cols = cols_for(os.path.join(SHEET_DIR, animal, filename))
        for direction, row in DIRECTIONS:
            if direction == 'side':
                row = SIDE_ROW_OVERRIDES.get((animal, anim), row)
            ids = []
            for col in range(cols):
                sid = f"af_{anim}_{direction}_{col}"
                ids.append(sid)
                lines.append(f'[sub_resource type="AtlasTexture" id="{sid}"]')
                lines.append(f'atlas = ExtResource("{tex_id[anim]}")')
                lines.append(f'region = Rect2({col * FRAME}, {row * FRAME}, {FRAME}, {FRAME})')
                lines.append('')
            frame_ids[(anim, direction)] = ids

    lines.append('[resource]')
    lines.append('animations = [{')
    entries = []
    for anim in sheets:
        loop, speed = ANIM_PARAMS[anim]
        for direction, _row in DIRECTIONS:
            ids = frame_ids[(anim, direction)]
            frame_blocks = []
            for fid in ids:
                frame_blocks.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % fid)
            frames_joined = ', '.join(frame_blocks)
            entry = (
                '"frames": [%s],\n"loop": %d,\n"name": &"%s_%s",\n"speed": %.1f'
                % (frames_joined, 1 if loop else 0, anim, direction, speed)
            )
            entries.append(entry)
    lines.append('\n}, {\n'.join(entries))
    lines.append('}]')
    lines.append('')
    return '\n'.join(lines)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for animal, sheets in CRITTERS.items():
        content = build(animal, sheets)
        out_path = os.path.join(OUT_DIR, f"{animal.lower()}_sprite_frames.tres")
        with open(out_path, 'w', newline='\n') as f:
            f.write(content)
        print(f"wrote {out_path}")


if __name__ == '__main__':
    main()
