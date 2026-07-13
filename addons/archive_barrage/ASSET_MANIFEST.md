# Asset manifest

## Poly Haven CC0

### Dark Rock 4K

- `assets/polyhaven/dark_rock_4k/dark_rock_diff_4k.jpg`
- `assets/runtime/dark_rock/dark_rock_normal_gl_4k.webp`
- `assets/polyhaven/dark_rock_4k/dark_rock_rough_4k.jpg`
- `assets/polyhaven/dark_rock_4k/dark_rock_disp_4k.jpg`

Назначение: локальные скальные выступы, каменные пятна и крупные неровности переднего плана. Не основной грунт.

### Plastered Stone Wall 4K/2K runtime normal

- `assets/polyhaven/plastered_stone_wall_4k/plastered_stone_wall_diff_4k.jpg`
- `assets/runtime/plastered_stone_wall/plastered_stone_wall_normal_gl_2k.webp`
- `assets/polyhaven/plastered_stone_wall_4k/plastered_stone_wall_rough_4k.jpg`
- `assets/polyhaven/plastered_stone_wall_4k/plastered_stone_wall_disp_4k.jpg`

Назначение: бетонные столбы, обломки, края укреплений. Не грунт.

### Rogland Clear Night 4K EXR

- `assets/polyhaven/rogland_clear_night_4k/rogland_clear_night_4k.exr`

Назначение: IBL, отражения и очень слабая естественная ночная подсветка. Видимый фон закрывается отдельным тёмным куполом.

## Generated PBR

### Steppe ground 4K

- albedo;
- normal GL;
- roughness;
- 16-bit height;
- AO;
- wet mask.

### Aged concrete 2K

- albedo;
- normal GL;
- roughness;
- 16-bit height.

### Old wire 1K

- albedo;
- roughness;
- metallic.

## Generated environment/support

- 8K archive sky;
- 8K far berm silhouette;
- 8K far fence silhouette;
- 8K fog band;
- 2K terrain heightmap;
- 8 puddle alpha masks;
- 6 mud decals;
- 2K smoke atlas 4×4;
- 2K smoke noise;
- 1K radial flash.

Все generated-файлы воспроизводимы через `tools/generate_assets.py`, seed `667`.

## Reference and previews

- `reference/original_barrage_reference.png` — исходный приложенный референс;
- `assets/generated/preview/target_composition_preview_2560x1440.jpg` — широкий композиционный target;
- `assets/generated/preview/generated_assets_contact_sheet.jpg` — проверка generated-карт;
- `assets/generated/preview/polyhaven_selection_contact_sheet.jpg` — выбранные внешние материалы и HDRI.
