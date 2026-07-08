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
- Legacy side drift multiplier: `chaos_multiplier`
- Overall scale/density feel: `density_multiplier`
- Vertical offset for the whole field: `cloud_height_offset`
- Shared wind vector: `wind_direction`
- Overall wind force: `wind_strength`
- Per-layer wind speeds:
  - `far_layer_speed`
  - `mid_layer_speed`
  - `accent_layer_speed`
- Internal wind/noise force: `turbulence_strength`
- Tiny per-cloud yaw motion: `rotation_drift_strength`
- Tiny per-cloud scale motion: `scale_breath_strength`
- Wrap/follow field size: `FIELD_HALF_EXTENTS`
- Per-layer positions, scale, alpha and ash-red tint:
  - `_far_layout()`
  - `_mid_layout()`
  - `_accent_layout()`

The current layout uses a wider `FIELD_HALF_EXTENTS` and scattered X/Z coordinates so the 13 clouds do not sit in one tight clump. Clouds are tinted toward a dirty ash-red palette in the layout tables and in the runtime cloud shader, so they should not read as neutral gray.

## Wind Flow

Cloud motion is still handled by the existing `SkyCloudsController` and the existing runtime `MeshInstance3D` planes. The movement now has several layers:

- shared wind from `wind_direction`, scaled by `wind_strength`;
- layer speeds through `far_layer_speed`, `mid_layer_speed`, and `accent_layer_speed`;
- per-cloud `wind_factor` and small individual velocity offsets;
- slow drift waves through `turbulence_axis`, `turbulence_speed`, and `turbulence_amount`;
- secondary crosswind flow through `flow_phase`, `flow_speed`, and `flow_amount`;
- vertical breathing through `vertical_phase`, `vertical_speed`, and `vertical_amount`;
- tiny yaw drift through `rotation_phase`, `rotation_speed`, and `rotation_amount`;
- weak scale breathing through `scale_phase`, `scale_speed`, and `scale_amount`.

`FAR_CLOUDS` should move heavily and slowly, but still drift over 10-20 seconds. `MID_CLOUDS` carry the main readable wind motion. `ACCENT_CLOUDS` move a little faster and can feel more nervous, but their speed and rotation are still capped to avoid an arcade look.

## Shader Turbulence

Cloud planes now use a lightweight runtime `ShaderMaterial` instead of `StandardMaterial3D`. The shader keeps the cleaned PNG alpha, stays transparent, disables shadows and depth writes, and adds a very weak UV distortion/flow using `TIME`.

The shader turbulence is deliberately minimal. It is meant to make the cloud mass feel like it is being pulled by wind, not to deform the PNG into a cartoon cloud or create rectangular cards.

## Adding New Cloud PNGs

Add a transparent PNG to `res://assets/textures/sky/clouds_runtime_clean/`.

Do not include `checkerboard`, `source`, `preview`, or `tonemap` in the filename unless the file should be ignored. After Godot imports the PNG, `SkyCloudsController` will include it automatically and create another cloud plane at runtime.
