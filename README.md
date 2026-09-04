# Pixel-RPG

A pixel-art, top-down, tile-based action-RPG built in Godot 4.7 / GDScript.

## Running it

Open the project in Godot and press Play — `scenes/main.tscn` is the main
scene. It spawns the Player (Pixel Crawler's Body_A) on top of
`Pixel-RPG.tscn`'s tilemap at the `PlayerSpawn` marker. Move the
`World/PlayerSpawn` marker in `scenes/main.tscn` to wherever you want the
player to start.

Default controls (`Project Settings > Input Map` to change):

| Action             | Key    |
|--------------------|--------|
| Move                | W A S D |
| Attack              | J |
| Interact            | E |
| Toggle inventory    | I |
| Pause               | Escape |

Arrow keys aren't bound by default — add them in the Input Map if you want both.

## Architecture

```
scripts/
  autoload/        Singletons: Events (signal bus), GameManager (global state),
                    UIManager (screen toggling)
  components/       Reusable Node/Area2D pieces attached to entities:
                    HealthComponent, StatsComponent, HitboxComponent,
                    HurtboxComponent, InteractionComponent
  entities/
    state.gd, state_machine.gd   Generic FSM used by both player and enemies
    entity_base.gd               Shared CharacterBody2D base (movement, damage)
    player/                      Player + its states (Idle/Move/Attack/Hurt/Dead)
    enemy/                       EnemyBase + its states (Idle/Chase/Attack/Hurt/Dead)
    npc/                         NPCBase (dialogue + interaction, no combat)
  items/            ItemBase and every item category (see below)
  world/            ItemPickup (world-space item drops)
  ui/               MenuBase, InventoryUI, HUD
  main.gd           Boots the game: spawns the player, wires up the world/UI

scenes/             .tscn counterparts for everything above that needs a node tree
resources/items/    Example .tres item instances, organized by category
resources/characters/  SpriteFrames resources built from assets/ (see Art below)

assets/             Pixel Crawler - Free Pack 2.11 (Anokolisa), copied in full
```

### Art: Pixel Crawler pack + SpriteFrames

All character art comes from `assets/Entities/...` (the full Pixel Crawler
Free Pack). Nothing engine-side reads those PNGs directly — each character's
sheets are sliced into a `SpriteFrames` resource under `resources/characters/`
(one `.tres` per character), which an `AnimatedSprite2D` node plays from.
No attribution is required to use the pack, but the author (email in
`assets/Terms.txt`) appreciates it if you do.

`EntityBase.play_animation(base_name)` (in `entity_base.gd`) is what every
state script calls (`play_animation("idle")`, `"walk"`, `"attack"`, `"hurt"`,
`"death"`). It handles two art conventions transparently:

- **Multi-directional** (the player, Body_A): animations are named
  `<base_name>_down/up/side`; `play_animation` derives the direction from
  `facing_direction` and flips `side` horizontally for leftward movement.
- **Single-direction** (all current mobs/NPCs): animations are just
  `<base_name>` with no suffix; the character always faces right in the art
  and `play_animation` flips the whole sprite (`flip_h`) for leftward
  movement instead.

`play_animation()` tries the exact name first, then falls back to the
directional form, so both conventions work through the same call — a state
script never needs to know which kind of art it's driving. It also returns
`false` and does nothing if the animation doesn't exist, so states that
reference an animation the current character doesn't have (see the mob/NPC
gap below) just silently keep showing whatever's already playing.

**Character roster** (`resources/characters/`):

| File | Source | Animations |
|------|--------|-------------|
| `player_sprite_frames.tres` | Characters/Body_A | idle/walk/attack/hurt/death × down/side/up |
| `enemies/orc*_sprite_frames.tres` (4: base, rogue, shaman, warrior) | Mobs/Orc Crew | idle, walk, death |
| `enemies/skeleton_*_sprite_frames.tres` (4: base, mage, rogue, warrior) | Mobs/Skeleton Crew | idle, walk, death |
| `npcs/knight_sprite_frames.tres`, `rogue_sprite_frames.tres`, `wizzard_sprite_frames.tres` | Npc's/ | idle, walk, death |
| `npcs/citizen_peasant_a_sprite_frames.tres`, `citizen_tavern_a_sprite_frames.tres`, `citizen_tavern_b_sprite_frames.tres` | Npc's/Citizen_F | idle, walk |

`enemy_base.tscn` defaults to `skeleton_warrior`; `npc_base.tscn` defaults to
`knight`. **To reskin one:** select its `AnimatedSprite2D` node and swap
`Sprite Frames` in the Inspector to any of the resources above (or generate
a new one — see the generator pattern below) — no script changes needed.

The free pack only ships Idle/Run/Death for mobs and NPCs (no Attack/Hurt
frames), so `EnemyBase`'s Attack and Hurt states currently play no animation
of their own — combat still works (damage, hitboxes, state transitions), the
sprite just keeps showing Idle/Walk through those states. Add Attack/Hurt
animations to a character's `SpriteFrames` (named exactly `attack`/`hurt`,
no suffix) and the existing states will pick them up with no code changes.

**Adding a new character**: build a `SpriteFrames` resource that slices
whatever sheets you're using into named animations (a texture region per
frame via `AtlasTexture`, `region = Rect2(frame_index * frame_width, 0,
frame_width, frame_height)`); the pattern used to generate every `.tres`
above was a small throwaway script that reads each sheet's pixel dimensions
and assumes square frames (frame edge = sheet height) except where a sheet's
canvas isn't square (rare — currently only Orc Warrior's Death animation).

### Why it's built this way

- **Components over inheritance.** Health, stats, hitboxes/hurtboxes, and
  interactions are separate nodes, not methods baked into the player/enemy
  scripts. The player, an enemy, and (optionally) an NPC can all reuse the
  same `HealthComponent` without sharing a class hierarchy for it.
- **A state machine per entity**, not a giant `match` statement in
  `_physics_process`. Each state (`PlayerAttackState`, `EnemyChaseState`, ...)
  is its own script/node, so combat logic doesn't creep into movement logic.
- **Items are `Resource`s, not scenes.** Every item (`Weapon`, `Armor`,
  `Tool`, `Ring`, `Amulet`, `Consumable`, `CraftingMaterial`) extends
  `ItemBase` and is authored as a `.tres` file — see `resources/items/` for
  one example per category. Add new items in the Inspector by right-clicking
  a folder → New Resource → pick the item type, no code required. This also
  means items serialize cleanly if/when you add a save system.
- **`Events` autoload** decouples systems that don't otherwise know about
  each other — e.g. `HUD` reacts to `Events.health_changed` instead of
  holding a reference to whatever entity took damage.

### Collision layer legend

| Layer | Value | Used by |
|-------|-------|---------|
| 1     | 1     | Solid bodies (player/enemy/NPC physical collision, walls) |
| 3     | 4     | Hurtboxes (things that can be hit) |
| 4     | 8     | Interactables (NPCs, chests, signs) |

Hitboxes mask onto layer 3 (hurtboxes); the player's `InteractionDetector`
masks onto layer 4; enemy `DetectionArea`s mask onto layer 1 (to spot the
player's physical body). Layer 2 is free for a future projectile layer.

### Extending it

- **New enemy**: duplicate `scenes/entities/enemy/enemy_base.tscn`, swap its
  `AnimatedSprite2D`'s `Sprite Frames` to one of the `resources/characters/enemies/`
  resources (or a new one), tune the exported stats, and fill in `loot_table`.
  No new script usually needed.
- **New item**: New Resource → pick `Weapon`/`Armor`/`Tool`/`Ring`/`Amulet`/
  `Consumable`/`CraftingMaterial`, fill in the Inspector fields, save as
  `.tres` under `resources/items/`.
- **New UI screen** (crafting menu, shop, map): extend `MenuBase`, set a
  unique `screen_name`, and open/close it via
  `UIManager.open_screen(&"your_screen")`.
- **Dialogue/quests**: `NPCBase` already exposes `dialogue_lines`,
  `start_dialogue()`, and `advance_dialogue()` — wire a `DialogueUI`
  (a `MenuBase` subclass) to `Events.dialogue_started` to display it.

### Known gaps (intentionally left for you)

- No Attack/Hurt animations for mobs/NPCs (see Art section above) — the free
  pack doesn't include them. Combat logic works regardless.
- Weapon overlay sprites (`assets/Weapons/`) aren't wired onto the player —
  the Slice/Pierce animations are drawn bare-handed for now.
- No save/load system.
- No shop/crafting/dialogue UI screens yet — `MenuBase` + `UIManager` give
  you the toggling mechanism; the screens themselves are up to you.
