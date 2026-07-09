# Mountain Megawall Backdrop System

Godot 4.7 layered distant mountain wall for the retro steppe scene.

## Current Integration

`scripts/steppe_environment_builder.gd` instances `res://systems/mountain_megawall/MountainMegawallRoot.tscn` when `mountain_megawall_enabled` is true.

The existing Lake Balkhash vista is built on the west/left side of the world at negative X. The megawall defaults to `mountain_megawall_yaw_degrees = 90.0`, which points east/+X, so it occupies the opposite side and does not cover the lake horizon.

Yaw convention:

- `0` = +Z
- `90` = +X
- `180` = -Z
- `270` or `-90` = -X, the Balkhash side in this project

Rotate the wall from the `SteppeEnvironment` node exports or directly on `MountainMegawallRoot.mountain_direction_yaw_degrees`.

## How It Works

The megawall is not playable terrain. It is a fake near-distance backdrop:

1. `RealForegroundRidge` builds a real low-poly non-colliding ridge around 112 meters toward the mountain side.
2. `FoothillsLayer`, `MainWallLayer`, `SnowPeakOverlayLayer`, and `RearPeakLayer` are curved cylindrical panorama strips.
3. `LowHazeLayer`, `MidHazeLayer`, `LowCloudLayer`, and `CloudShadowLayer` soften card edges and add depth.
4. `NightLightsLayer` fades in only at night.
5. `MicroEventController` creates rare subtle events: tiny station light, industrial flash, storm flash, aircraft blink, and avalanche/snow drift.

`MountainMegawallRoot` follows the active `Camera3D` on X/Z and keeps Y at `fixed_y`, so the player never reaches the fake mountains and the arc edges remain hidden.

## Production Textures

Runtime materials use:

```text
res://art/backdrops/mountains/megawall/textures/production/
```

Generated files include 8K main/rear/snow sheets, 4K haze/cloud/foothill sheets, and 2K masks. They were generated with:

```powershell
node .\tools\generate_mountain_megawall_production_textures.js
```

The original archive placeholders remain in:

```text
res://art/backdrops/mountains/megawall/textures/placeholder/
```

If production textures are missing and placeholders are present, the root prints a non-fatal warning.

## Legal Sources

See:

```text
res://art/backdrops/mountains/megawall/LICENSES_AND_SOURCES.md
```

Current production sheets are deterministic project-generated procedural images. No map tiles, satellite imagery, ripped photos, or unknown-license images are baked into them.

Acceptable final replacement sources:

- CC0 Poly Haven HDRIs and PBR textures
- CC0 ambientCG rock, cliff, snow, gravel, scree, and soil textures
- CC0 OpenHDRI skies
- legally downloaded OpenTopography, Copernicus DEM GLO-30, or NASA/SRTM DEM data
- Wikimedia/Flickr/Openverse assets only when commercial modification is allowed

Forbidden final sources:

- Google Earth or Google Maps imagery
- Yandex Maps
- Bing Maps
- Pinterest or unknown-license photos
- NonCommercial or NoDerivatives assets
- copyrighted photos without explicit permission

## Best Offline Art Upgrade

If Blender or a terrain renderer is available later:

1. Download a legal DEM around Tien Shan / Khan Tengri / Jengish Chokusu / Inylchek Glacier.
2. Build a non-playable terrain in Blender, QGIS plus Blender, Gaea, or Terragen.
3. Use CC0 rock/snow/scree materials.
4. Render telephoto/panoramic strips:
   - day beauty
   - night beauty
   - alpha
   - depth/mist
   - snow mask
   - cloud shadow mask
   - emission/night lights mask
   - haze and low cloud passes
5. Replace files in `textures/production/`, keeping similar aspect ratios.

Do not import a single 32K texture directly into Godot. Use 8K/4K sheets or split larger renders into tiles.

## Tuning

- If the wall covers too much sky, reduce `MainWallLayer.height` or increase its `radius`.
- If it looks flat, increase radius separation, strengthen low haze, or raise the foreground ridge.
- If it looks like a postcard, reduce `contrast`, raise `haze_strength`, and darken/desaturate day textures.
- If the lake is blocked, make sure the yaw is not `270` or `-90`.

## Performance Presets

`MountainMegawallRoot.performance_preset`:

- `LOW`: fewer segments, no cloud shadow layer, no night lights, no events
- `MEDIUM`: main layers and haze/clouds, no cloud shadows or events
- `HIGH`: cloud shadows, night lights, rare events
- `CINEMATIC`: all effects and higher arc segment counts

## Debug

Useful root options:

- `debug_print_direction`
- `debug_show_layer_radii`
- `debug_show_layers`
- `freeze_backdrop_time`
- `warn_when_using_placeholder_textures`
- `debug_force_day_night_enabled` plus `debug_forced_day_night`
- `debug_force_haze_enabled` plus `debug_forced_haze_strength`
- `show_foreground_ridge`
- `show_foothills_layer`
- `show_main_wall_layer`
- `show_snow_peak_overlay_layer`
- `show_rear_peak_layer`
- `show_low_haze_layer`
- `show_mid_haze_layer`
- `show_low_cloud_layer`
- `show_cloud_shadow_layer`
- `show_night_lights_layer`

The layer visibility toggles are still constrained by the active performance preset. For example, `LOW` keeps cloud shadows and night lights disabled even when their debug toggles are true.

Force a rare event at runtime with:

```gdscript
$MountainMegawallRoot.debug_force_event("distant_storm_flash")
```

Valid names include `tiny_light_pulse`, `distant_storm_flash`, `industrial_flash`, `aircraft_blink`, and `avalanche_drift`.

## Verification

Run:

```powershell
& 'C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --editor --path 'C:\GameDev\retro_journal_proto' --quit
& 'C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'C:\GameDev\retro_journal_proto' 'res://scenes/Main.tscn' --quit-after 1
& 'C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path 'C:\GameDev\retro_journal_proto' 'res://scenes/levels/InfiniteRoad.tscn' --quit-after 1
```
