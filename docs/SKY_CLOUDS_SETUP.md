# Sky Clouds Setup

The outdoor steppe sky keeps the existing sky dome/HDRI base and adds runtime cloud planes through `res://scripts/sky_clouds_controller.gd`.

Runtime clouds use cleaned PNGs from:

`res://assets/textures/sky/clouds_runtime_clean/`

## Runtime Structure

`SkyCloudsController` creates this node tree at runtime in `Main.tscn`:

- `SkyClouds`
- `SkyClouds/FAR_CLOUDS`
- `SkyClouds/MID_CLOUDS`
- `SkyClouds/ACCENT_CLOUDS`

Every eligible cleaned cloud PNG creates one `MeshInstance3D` plane. If the folder contains 9 eligible cloud PNGs, the runtime scene creates at least 9 cloud planes. With the current folder, it creates 13 cloud planes.

## Used Cloud PNG Files

These cleaned files are used as cloud textures:

### FAR_CLOUDS

- `res://assets/textures/sky/clouds_runtime_clean/cloud_01.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_02.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_03.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_04.png`

### MID_CLOUDS

- `res://assets/textures/sky/clouds_runtime_clean/cloud_05.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_06.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_07.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_08.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_09.png`

### ACCENT_CLOUDS

- `res://assets/textures/sky/clouds_runtime_clean/cloud_10.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_11.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_12.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_13.png`

## Ignored Sky Files

The runtime scanner ignores:

- `*.import`
- source files outside `clouds_runtime_clean/`
- names containing `checkerboard`, `source`, `preview`, or `tonemap`

The EXR/sky texture remains the base sky dome and is not used as a cloud card.

Original source-to-cleaned mapping and transparency notes are in:

`res://docs/SKY_CLOUDS_TRANSPARENCY_FIX.md`

## Tuning

Edit `res://scripts/sky_clouds_controller.gd`.

- Overall speed: `speed_multiplier`
- Side drift and vertical breathing strength: `chaos_multiplier`
- Overall scale/density feel: `density_multiplier`
- Vertical offset for the whole field: `cloud_height_offset`
- Wrap/follow field size: `FIELD_HALF_EXTENTS`
- Per-layer positions, scale, alpha, speed and movement direction:
  - `_far_layout()`
  - `_mid_layout()`
  - `_accent_layout()`

The current layout uses a wider `FIELD_HALF_EXTENTS` and scattered X/Z coordinates so the 13 clouds do not sit in one tight clump. Each cloud also gets a deterministic side-drift axis in `_drift_axis()`, so movement is less uniform while staying stable between launches.

## Adding New Cloud PNGs

Add a transparent PNG to `res://assets/textures/sky/clouds_runtime_clean/`.

Do not include `checkerboard`, `source`, `preview`, or `tonemap` in the filename unless the file should be ignored. After Godot imports the PNG, `SkyCloudsController` will include it automatically and create another cloud plane at runtime.
