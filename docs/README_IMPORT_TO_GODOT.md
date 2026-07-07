# Godot Steppe + Sky Asset Notes

Copy/import assets into:

`C:\GameDev\retro_journal_proto\`

## Sky / Clouds

- `res://assets/textures/sky/sky_mud_road_puresky_1k.exr` is the base sky texture.
- `res://assets/textures/sky/sky_mud_road_puresky_1k_tonemap.png` is only a preview/fallback and is not used as a cloud.
- Cleaned transparent cloud PNGs in `res://assets/textures/sky/clouds_runtime_clean/` are loaded at runtime by `res://scripts/sky_clouds_controller.gd`.
- Source cloud PNGs in `res://assets/textures/sky/` are kept for reference and should not be rendered directly if they contain baked-in checkerboard backgrounds.
- Files with `checkerboard`, `source`, or `tonemap` in the name are ignored by the cloud scanner.
- Runtime layers are `SkyClouds/FAR_CLOUDS`, `SkyClouds/MID_CLOUDS`, and `SkyClouds/ACCENT_CLOUDS`.

See `res://docs/SKY_CLOUDS_SETUP.md` for the current cloud list and tuning notes.

## Ground

- `res://assets/textures/ground/tex_steppe_dry_ground_1024.png`
- `res://assets/textures/ground/tex_steppe_dry_ground_dark_1024.png`
- `res://assets/textures/ground/tex_steppe_detail_mask_1024.png`

## Models

- `res://assets/models/flowers/low_poly_flowers_uploaded.glb`
- `res://assets/models/flowers/flowers_uploaded.glb`
- `res://assets/models/props/lowpoly_power_pylon_no_wires.glb`
- `res://assets/models/vegetation_fallback/fallback_grass_patch.glb`
- `res://assets/models/vegetation_fallback/fallback_flower_red.glb`
- `res://assets/models/vegetation_fallback/fallback_flower_white.glb`
- `res://assets/models/vegetation_fallback/fallback_flower_yellow.glb`

## Scripts

- `res://scripts/steppe_environment_builder.gd` builds the ground, sky dome, power pylon, and vegetation.
- `res://scripts/sky_clouds_controller.gd` builds and animates the dynamic cloud field.

## Notes

- SkyDome and cloud planes should not have collision.
- Cloud materials are created unshaded, transparent, cull-disabled, and shadowless.
- The cloud field follows the player on X/Z and wraps individual clouds inside the field.
