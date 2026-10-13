# RPG-Font (bitmap font)

Generated from `RPG-Font.png` (a hand-drawn type specimen). The source sheet draws each
letter as a fused `Aa Bb Cc …` pair; this font splits every pair back into separate
upper- and lowercase glyphs, plus the digit and punctuation rows.

## Files
| File | Purpose |
|------|---------|
| `RPG-Font.fnt` | AngelCode/BMFont descriptor. Import this into Godot. |
| `RPG-Font_bitmap.png` | Glyph atlas the `.fnt` points at. Keep it next to the `.fnt`. |
| `RPG-Font.png` | Original specimen art (kept for reference; not used at runtime). |

## Metrics
- line height 12 px, baseline 8 px, cap height 8 px, 1 px letter spacing, space = 4 px
- letters/digits: `A–Z`, `a–z`, `0–9`
- punctuation: `. , ! ? : ; ' \` " ( ) [ ] / \ | & - _`
- dingbat row (hand-drawn ornaments, best-effort identification — remap the keys in
  `tools/build_rpg_font.py` if you disagree):
  - digit-row tail → `= × *` `•` (U+2022 bullet) `◆` (U+25C6 black diamond)
  - bottom row → `< >` and `«` `»` (U+00AB/00BB guillemets; swap to `{` `}` in the script
    if you'd rather have braces)
- not in the source art: `@ $ % ^ + ~` and `{ }` (unless you switch the guillemets over)

## Use in Godot 4
1. The files are already under `res://assets/UI/`. Open the editor once so it imports
   `RPG-Font.fnt` as a **FontFile**.
2. Point a control at it, e.g. on a `Label`:
   - Inspector → Theme Overrides → Fonts → Font → load `RPG-Font.fnt`
   - Theme Overrides → Font Sizes → Font Size → `10` (or any multiple: 20, 30, 40 for
     crisp 2x/3x/4x — it's a bitmap, so stick to multiples of 10)
3. For a project-wide default, add it to your `Theme` under `Label/fonts/font` (and
   `Button`, `RichTextLabel`, …).
4. Keep texture filtering on **Nearest** (Project Settings → Rendering → Textures →
   Canvas Textures → Default Texture Filter = Nearest) so it stays pixel-crisp.

## Regenerating
See `tools/` — the build script lives with the session notes; rerun it if the source
art changes.
