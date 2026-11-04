"""
Generates .tscn scene files for every enemy that has a sprite_frames .tres
in resources/characters/enemies/ but no scene in scenes/entities/enemy/.

Each scene mirrors the structure of enemy_base.tscn: CharacterBody2D root
with AnimatedSprite2D, collision shapes, health/stats/hurtbox/hitbox,
detection area, footstep player, and a state machine (Idle/Wander/Chase/
Attack/Hurt/Dead).

Usage:  python tools/build_enemy_scenes.py
"""
from __future__ import annotations
import os
import re
from typing import Dict, List, Tuple

ROOT = os.path.join(os.path.dirname(__file__), "..")
FRAMES_DIR = os.path.join(ROOT, "resources", "characters", "enemies")
SCENES_DIR = os.path.join(ROOT, "scenes", "entities", "enemy")

# slug -> (display_name, hp, atk, move_speed, sprint_speed, xp,
#          wander_radius, detect_radius, body_shape, hurt_shape, hit_shape)
# Shapes are (w, h) for RectangleShape2D.
# body_offset_y, hurt_offset_y are vertical offsets for the shape centers.

SMALL_BODY = (13, 11.5)
SMALL_HURT = (14, 16)
SMALL_HIT = (14, 8)

MED_BODY = (16, 14)
MED_HURT = (18, 20)
MED_HIT = (16, 10)

LARGE_BODY = (20, 16)
LARGE_HURT = (22, 24)
LARGE_HIT = (18, 12)

ENEMY_DEFS: Dict[str, Tuple] = {
    # Skeleton Crew (Grasslands, tier 1)
    "skeleton_base":  ("SkeletonBase",  12, 2, 35, 65, 4,  80, 120, SMALL_BODY, SMALL_HURT, SMALL_HIT),
    "skeleton_mage":  ("SkeletonMage",  10, 4, 30, 55, 6,  70, 110, SMALL_BODY, SMALL_HURT, SMALL_HIT),
    "skeleton_rogue": ("SkeletonRogue", 10, 3, 45, 80, 5,  90, 130, SMALL_BODY, SMALL_HURT, SMALL_HIT),

    # Orc Crew (Grasslands, tier 1-2)
    "orc":          ("Orc",         18, 3, 35, 60, 6,  80, 120, SMALL_BODY, SMALL_HURT, SMALL_HIT),
    "orc_rogue":    ("OrcRogue",    14, 4, 45, 80, 7,  90, 130, SMALL_BODY, SMALL_HURT, SMALL_HIT),
    "orc_shaman":   ("OrcShaman",   12, 5, 30, 55, 8,  70, 110, SMALL_BODY, SMALL_HURT, SMALL_HIT),
    "orc_warrior":  ("OrcWarrior",  25, 5, 30, 65, 10, 80, 130, SMALL_BODY, SMALL_HURT, SMALL_HIT),

    # Rat (Sewer, tier 1)
    "rat_base":    ("RatBase",    8,  2, 40, 70, 3,  60, 100, SMALL_BODY, SMALL_HURT, SMALL_HIT),
    "rat_mage":    ("RatMage",    6,  3, 35, 60, 4,  60, 100, SMALL_BODY, SMALL_HURT, SMALL_HIT),
    "rat_rogue":   ("RatRogue",   7,  3, 50, 85, 4,  70, 110, SMALL_BODY, SMALL_HURT, SMALL_HIT),
    "rat_warrior": ("RatWarrior", 12, 3, 35, 65, 5,  70, 110, SMALL_BODY, SMALL_HURT, SMALL_HIT),

    # Fungus (Cave, tier 2)
    "immature_fungus": ("ImmatureFungus", 15, 3, 25, 45, 5,  60, 100, MED_BODY, MED_HURT, MED_HIT),
    "long_fungus":     ("LongFungus",     18, 4, 30, 50, 7,  70, 110, MED_BODY, MED_HURT, MED_HIT),
    "heavy_fungus":    ("HeavyFungus",    30, 5, 20, 35, 10, 60, 100, LARGE_BODY, LARGE_HURT, LARGE_HIT),
    "old_fungus":      ("OldFungus",      22, 4, 25, 45, 8,  60, 100, MED_BODY, MED_HURT, MED_HIT),

    # Mummy (Desert, tier 2)
    "mummy_base":    ("MummyBase",    20, 3, 30, 50, 7,  80, 120, MED_BODY, MED_HURT, MED_HIT),
    "mummy_mage":    ("MummyMage",    15, 5, 25, 45, 8,  70, 110, MED_BODY, MED_HURT, MED_HIT),
    "mummy_rogue":   ("MummyRogue",   16, 4, 40, 70, 8,  80, 120, MED_BODY, MED_HURT, MED_HIT),
    "mummy_warrior": ("MummyWarrior", 28, 5, 30, 55, 10, 80, 130, MED_BODY, MED_HURT, MED_HIT),

    # Elf (Fairy Forest, tier 2-3)
    "elf_base":   ("ElfBase",   18, 4, 40, 70, 8,  90, 130, MED_BODY, MED_HURT, MED_HIT),
    "elf_druid":  ("ElfDruid",  16, 5, 35, 60, 9,  80, 120, MED_BODY, MED_HURT, MED_HIT),
    "elf_hunter": ("ElfHunter", 20, 5, 45, 75, 10, 100, 140, MED_BODY, MED_HURT, MED_HIT),
    "elf_ranger": ("ElfRanger", 18, 6, 40, 70, 10, 100, 140, MED_BODY, MED_HURT, MED_HIT),

    # Stone (Forge, tier 3)
    "stone_base":   ("StoneBase",   30, 5, 25, 40, 10, 60, 100, LARGE_BODY, LARGE_HURT, LARGE_HIT),
    "stone_broken": ("StoneBroken", 20, 4, 30, 45, 8,  70, 110, MED_BODY, MED_HURT, MED_HIT),
    "stone_golem":  ("StoneGolem",  45, 7, 20, 35, 15, 60, 100, LARGE_BODY, LARGE_HURT, LARGE_HIT),
    "stone_lava":   ("StoneLava",   35, 8, 25, 40, 14, 60, 100, LARGE_BODY, LARGE_HURT, LARGE_HIT),

    # Garden (tier 2)
    "feminine":  ("GardenFeminine",  20, 4, 30, 55, 7,  70, 110, MED_BODY, MED_HURT, MED_HIT),
    "masculine": ("GardenMasculine", 22, 5, 30, 55, 8,  70, 110, MED_BODY, MED_HURT, MED_HIT),
    "medusa":    ("Medusa",          25, 6, 25, 50, 10, 80, 120, MED_BODY, MED_HURT, MED_HIT),
    "old":       ("GardenOld",       18, 3, 25, 45, 6,  60, 100, MED_BODY, MED_HURT, MED_HIT),

    # Hideout (tier 2)
    "scout":    ("Scout",    14, 3, 50, 80, 6,  100, 140, MED_BODY, MED_HURT, MED_HIT),
    "fighter":  ("Fighter",  22, 5, 35, 60, 8,  80,  120, MED_BODY, MED_HURT, MED_HIT),
    "tracker":  ("Tracker",  18, 4, 40, 70, 7,  90,  130, MED_BODY, MED_HURT, MED_HIT),
    "sorcerer": ("Sorcerer", 14, 6, 30, 55, 9,  70,  110, MED_BODY, MED_HURT, MED_HIT),

    # Royal Crew - Grasslands (tier 2-3)
    "grasslands_soldier": ("GrasslandsSoldier", 22, 4, 35, 60, 8,  80, 120, MED_BODY, MED_HURT, MED_HIT),
    "grasslands_archer":  ("GrasslandsArcher",  16, 5, 40, 65, 8,  100, 140, MED_BODY, MED_HURT, MED_HIT),
    "grasslands_knight":  ("GrasslandsKnight",  30, 6, 30, 55, 12, 80, 120, MED_BODY, MED_HURT, MED_HIT),
    "grasslands_priest":  ("GrasslandsPriest",  18, 3, 30, 50, 9,  70, 110, MED_BODY, MED_HURT, MED_HIT),

    # Royal Crew - Castle (tier 3)
    "castle_soldier": ("CastleSoldier", 28, 5, 35, 60, 10, 80, 120, MED_BODY, MED_HURT, MED_HIT),
    "castle_archer":  ("CastleArcher",  20, 6, 40, 65, 10, 100, 140, MED_BODY, MED_HURT, MED_HIT),
    "castle_knight":  ("CastleKnight",  38, 7, 30, 55, 15, 80, 120, LARGE_BODY, LARGE_HURT, LARGE_HIT),
    "castle_priest":  ("CastlePriest",  22, 4, 30, 50, 12, 70, 110, MED_BODY, MED_HURT, MED_HIT),
}

# Skip enemies that already have hand-tuned scenes
SKIP = {"skeleton_warrior", "wolf"}

SCENE_TEMPLATE = """\
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/entities/enemy/enemy_base.gd" id="1"]
[ext_resource type="Script" path="res://scripts/entities/state_machine.gd" id="2"]
[ext_resource type="Script" path="res://scripts/entities/ai_idle_state.gd" id="3"]
[ext_resource type="Script" path="res://scripts/entities/enemy/states/enemy_chase_state.gd" id="4"]
[ext_resource type="Script" path="res://scripts/entities/enemy/states/enemy_attack_state.gd" id="5"]
[ext_resource type="Script" path="res://scripts/entities/ai_hurt_state.gd" id="6"]
[ext_resource type="Script" path="res://scripts/entities/dead_state.gd" id="7"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="8"]
[ext_resource type="Script" path="res://scripts/components/stats_component.gd" id="9"]
[ext_resource type="Script" path="res://scripts/components/hurtbox_component.gd" id="10"]
[ext_resource type="Script" path="res://scripts/components/hitbox_component.gd" id="11"]
[ext_resource type="SpriteFrames" path="res://resources/characters/enemies/{slug}_sprite_frames.tres" id="12"]
[ext_resource type="Script" path="res://scripts/entities/ai_wander_state.gd" id="13"]
[ext_resource type="Script" path="res://scripts/components/shadow_component.gd" id="14"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_body"]
size = Vector2({body_w}, {body_h})

[sub_resource type="RectangleShape2D" id="RectangleShape2D_hurt"]
size = Vector2({hurt_w}, {hurt_h})

[sub_resource type="RectangleShape2D" id="RectangleShape2D_hit"]
size = Vector2({hit_w}, {hit_h})

[sub_resource type="CircleShape2D" id="CircleShape2D_detect"]
radius = {detect_radius}

[node name="{node_name}" type="CharacterBody2D"]
script = ExtResource("1")
xp_reward = {xp}
wander_radius = {wander_radius:.1f}
move_speed = {move_speed:.1f}
sprint_speed = {sprint_speed:.1f}

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
sprite_frames = ExtResource("12")
animation = &"idle"

[node name="Shadow" type="Sprite2D" parent="."]
position = Vector2(0, {shadow_y})
scale = Vector2({shadow_w}, {shadow_h})
z_index = -1
show_behind_parent = true
script = ExtResource("14")
shadow_width = {shadow_w:.1f}
shadow_height = {shadow_h:.1f}
shadow_offset = Vector2(0, {shadow_y})

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
visible = false
position = Vector2(0, {body_offset_y})
shape = SubResource("RectangleShape2D_body")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("8")
max_health = {hp:.1f}

[node name="StatsComponent" type="Node" parent="."]
script = ExtResource("9")
base_attack = {atk:.1f}

[node name="HurtboxComponent" type="Area2D" parent="."]
visible = false
position = Vector2(0, {hurt_offset_y})
collision_layer = 4
collision_mask = 0
script = ExtResource("10")

[node name="CollisionShape2D" type="CollisionShape2D" parent="HurtboxComponent"]
shape = SubResource("RectangleShape2D_hurt")

[node name="HitboxComponent" type="Area2D" parent="."]
visible = false
collision_layer = 0
collision_mask = 4
monitoring = false
script = ExtResource("11")
damage = {atk:.1f}

[node name="CollisionShape2D" type="CollisionShape2D" parent="HitboxComponent"]
position = Vector2({hit_offset_x}, 0)
shape = SubResource("RectangleShape2D_hit")

[node name="DetectionArea" type="Area2D" parent="."]
visible = false
collision_layer = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="DetectionArea"]
shape = SubResource("CircleShape2D_detect")

[node name="StateMachine" type="Node" parent="."]
script = ExtResource("2")
initial_state = &"Idle"

[node name="Idle" type="Node" parent="StateMachine"]
script = ExtResource("3")
min_idle_time = 5.0
max_idle_time = 12.0

[node name="Wander" type="Node" parent="StateMachine"]
script = ExtResource("13")

[node name="Chase" type="Node" parent="StateMachine"]
script = ExtResource("4")
sprint_when_chasing = true

[node name="Attack" type="Node" parent="StateMachine"]
script = ExtResource("5")

[node name="Hurt" type="Node" parent="StateMachine"]
script = ExtResource("6")

[node name="Dead" type="Node" parent="StateMachine"]
script = ExtResource("7")
linger_time = 14.0
"""


def main():
    os.makedirs(SCENES_DIR, exist_ok=True)

    existing_scenes = {
        f.replace(".tscn", "")
        for f in os.listdir(SCENES_DIR)
        if f.endswith(".tscn")
    }

    available_frames = {
        f.replace("_sprite_frames.tres", "")
        for f in os.listdir(FRAMES_DIR)
        if f.endswith("_sprite_frames.tres")
    }

    written = 0
    for slug in sorted(available_frames):
        if slug in SKIP:
            print(f"  skip {slug} (hand-tuned scene exists)")
            continue

        if slug not in ENEMY_DEFS:
            print(f"  skip {slug} (no stats defined)")
            continue

        node_name, hp, atk, move_speed, sprint_speed, xp, wander_radius, detect_radius, body_shape, hurt_shape, hit_shape = ENEMY_DEFS[slug]

        # Determine sizing context from body shape
        body_w, body_h = body_shape
        hurt_w, hurt_h = hurt_shape
        hit_w, hit_h = hit_shape

        is_small = body_shape == SMALL_BODY
        body_offset_y = 10.0 if is_small else 6.0
        hurt_offset_y = 1.0 if is_small else 2.0
        hit_offset_x = 9.0 if is_small else 12.0
        shadow_y = 14 if is_small else 10
        shadow_w = 22 if is_small else 28
        shadow_h = 9 if is_small else 10

        content = SCENE_TEMPLATE.format(
            slug=slug,
            node_name=node_name,
            hp=hp, atk=atk,
            move_speed=move_speed, sprint_speed=sprint_speed,
            xp=xp, wander_radius=wander_radius,
            detect_radius=detect_radius,
            body_w=body_w, body_h=body_h,
            hurt_w=hurt_w, hurt_h=hurt_h,
            hit_w=hit_w, hit_h=hit_h,
            body_offset_y=body_offset_y,
            hurt_offset_y=hurt_offset_y,
            hit_offset_x=hit_offset_x,
            shadow_y=shadow_y, shadow_w=shadow_w, shadow_h=shadow_h,
        )

        out = os.path.join(SCENES_DIR, f"{slug}.tscn")
        with open(out, "w", newline="\n") as f:
            f.write(content)
        print(f"wrote {slug}.tscn")
        written += 1

    print(f"\n{written} enemy scenes written to {SCENES_DIR}")


if __name__ == "__main__":
    main()
