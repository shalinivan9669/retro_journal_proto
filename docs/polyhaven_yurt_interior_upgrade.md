# Poly Haven Yurt Interior Upgrade

Phase 2 adds a runtime interior dressing pass for the existing yurt and upgrades only the basement walls. It does not replace `Main.tscn`, player movement, interaction logic, the cube cutscene, the road door, or the existing landscape surface.

## Runtime entry points

- `res://scripts/interior/yurt_interior_dressing_builder.gd`
  - Attached to `Main.tscn` as `YurtInteriorDressingBuilder`.
  - Enlarges the existing yurt root/collision in XZ by `yurt_scale_xz`.
  - Applies `fabric_leather_02` only to mesh names beginning with `YurtWall_`.
  - Adds non-colliding rugs, throws, hides, flags, low table, bed, screen, media props, generator, and exterior console table.
- `res://scripts/interior/yurt_textile_library.gd`
  - Builds thick draped textile meshes with folds, side faces, irregular hides, folded stacks, and flags.
- `res://scripts/interior/yurt_prop_replacement_manager.gd`
  - Loads Poly Haven prop glTFs from `res://assets/polyhaven/props/`.
  - Falls back to simple procedural props if an asset is missing.
- `res://scripts/interior/yurt_held_device_manager.gd`
  - Replaces the old flat phone overlay presentation with a held 3D cassette-player viewmodel while preserving the existing toggle path.
- `res://scripts/interior/basement_wall_upgrade_builder.gd`
  - Shared constants/material access for the basement wall upgrade.

## Asset tools

- `tools/download_polyhaven_interior_assets.py`
  - Downloads the requested Poly Haven models and texture sets.
  - Default output goes under `assets/polyhaven/props/`, `assets/polyhaven/textures/`, and `assets/polyhaven/interior_textiles/`.
- `tools/process_polyhaven_interior_assets_blender.py`
  - Optional Blender processing/export helper.
  - Safe to keep unused; the runtime can load the downloaded glTF files directly after Godot import.

## Materials

- Basement walls use `res://materials/polyhaven/mat_basement_broken_brick_wall.tres`.
- Yurt walls use `res://materials/polyhaven/textiles/mat_yurt_wall_fabric_leather_02.tres`.
- Interior textiles use:
  - `mat_velour_velvet_hero.tres`
  - `mat_curly_teddy_checkered_thick.tres`
  - `mat_quatrefoil_jacquard_tablecloth.tres`
  - `mat_wool_boucle_heavy.tres`
  - `mat_waffle_pique_cotton_flags.tres`

## Debug switches

On `YurtInteriorDressingBuilder`:

- `interior_upgrade_enabled`
- `textile_density_level`
- `use_ultra_textile_quality`
- `enlarge_yurt_enabled`
- `add_low_table_enabled`
- `add_screen_enabled`
- `replace_media_props_enabled`
- `add_bed_enabled`
- `add_exterior_props_enabled`
- `debug_hide_textiles`
- `debug_hide_new_props`

## Verification

After downloading/importing assets, verify these scenes:

```powershell
& 'C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'C:\GameDev\retro_journal_proto' --quit-after 1
& 'C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'C:\GameDev\retro_journal_proto' 'res://scenes/Main.tscn' --quit-after 1
& 'C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'C:\GameDev\retro_journal_proto' 'res://scenes/levels/InfiniteRoad.tscn' --quit-after 1
& 'C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'C:\GameDev\retro_journal_proto' 'res://scenes/levels/UndergroundSteppe.tscn' --quit-after 1
```
