# Yurt visual audit — baseline before stage 1

## Global Environment writers

- `scripts/visual_quality_preset.gd`, node `Main/VisualQualityPreset`: `_ready()` called `_apply_environment_preset()` and wrote tonemap, ambient, fog, adjustments, SSAO/SSIL, glow, and volumetric fog. It also called `_apply_light_preset()` for `Main/DirectionalLight3D` and `Main/RoomFillLight`.
- `scripts/visuals/retro_visuals_runtime.gd`, node `Main/VisualEffectsRuntime`: `tune_world_environment = true` called `_tune_world_environment()` and overwrote glow, adjustments, ambient energy, fog density, and fog color after scene load.
- `scripts/yurt_window_vision.gd`, node `Main/YurtWindowVision`: stores `Main/WorldEnvironment.environment`, animates `fog_density` toward `0.055` only during the window-vision story event, then restores the saved value.

## Baseline Environment values and conflicting runtime values

- `scenes/Main.tscn`, `Environment_room`: `ambient_light_color = (0.72, 0.64, 0.52)`, `ambient_light_energy = 0.96`, `fog_enabled = true`, `fog_density = 0.0016`.
- `scripts/visual_quality_preset.gd`: ambient `0.96`, fog `0.0016`, contrast `1.08`, saturation `0.88`, brightness `0.98`, glow intensity `0.18`, strength `0.42`, bloom `0.04`.
- `scripts/visuals/retro_visuals_runtime.gd`: ambient `0.34`, fog `0.0035`, contrast `1.12`, saturation `0.82`, glow intensity `0.22`, strength `0.55`.

## Runtime lights inside the yurt

- Scene lights in `scenes/Main.tscn`: `DirectionalLight3D` energy `1.85`; `RoomFillLight` energy `4.2`, range `22`; `YurtFloorBounceLight` energy `3.0`, range `11.5`; `YurtEntranceWarmFill` energy `1.35`, range `8`; `SignalCenterGlow` energy `0.76`, range `4.2`; `BullHeadBloodGlow` energy `0.35`, range `3.6`.
- `scripts/visuals/retro_visuals_runtime.gd` creates `TVColdScreenLight` as an unshadowed `OmniLight3D`, energy `0.55`, range `3.0`, and `RadioAmberDisplayLight`, energy `0.16`, range `1.4`.
- `scripts/yurt_window_vision.gd` creates `RoundWindowOutsideLight`, energy `0.45`; it is part of the window-vision system.
- `scripts/interior/yurt_interior_dressing_builder.gd` creates additional interior practical lights with runtime energy assignments at lines 303, 324, and 337; these are not global Environment writers.

## Runtime material ownership

- `scenes/Main.tscn` assigns `materials/mat_yurt_wall.tres` to `CleanYurt/world/YurtWall_Entrance_*` and `YurtWall_01..07`; roof and wood nodes use `mat_yurt_roof.tres` and `mat_yurt_wood_dark.tres`.
- `scripts/yurt_window_vision.gd` selects every mesh whose name begins with `YurtWall_`, sets `cast_shadow` off, and installs its runtime cutout material on all selected walls.
- `scripts/tv_video_screen.gd`, node `InteractableTV/TVVideoScreen`, is the authoritative owner of `VisibleTVModel/Screen` surface material and its `VideoTexture`/fallback emission.
- `scripts/visuals/retro_visuals_runtime.gd` does not override the TV screen material (`override_screen_material = false`), but it overrides the radio display material with `materials/devices/mat_radio_display_glow.tres`.

## Textured materials and mipmaps

- Active yurt wall/roof/wood resources in `scenes/Main.tscn` are color-only `StandardMaterial3D` resources: `materials/mat_yurt_wall.tres`, `mat_yurt_roof.tres`, `mat_yurt_wood_dark.tres`.
- Textured yurt alternatives exist in `materials/yurt/mat_yurt_wall_weathered_felt.tres` and `mat_yurt_roof_smoked_felt.tres`, using `assets/textures/yurt/yurt_interior_weathered_felt_v2.png`.
- Textured floor resources are under `materials/yurt_floor/`; albedo/roughness inputs come from `assets/yurt_floor_texture_pack/` and `assets/textures/yurt/yurt_main_worn_kazakh_rug_v2.png`.
- All inspected yurt wall and floor texture `.import` files have `mipmaps/generate=true`: weathered felt, worn rug, felt warm gray/deep red, felt roughness/detail, checkered albedo/detail, fabric albedos/roughness, and ornamental albedos.

## Stage 1 ownership after the patch

- `Main/YurtVisualDirector` is authoritative for global `Environment`, `DirectionalLight3D`, `RoomFillLight`, TV-light settings, ReflectionProbe enabled state (when a path is assigned), and diagnostic switches.
- `Main/VisualQualityPreset` retains viewport quality toggles only at runtime; legacy environment/light functions remain present but are no longer called. `enable_scene_details = false`.
- `Main/VisualEffectsRuntime` retains device emission, local device glitch, optional story/outdoor effects, and device-light construction; `tune_world_environment = false`, while authoritative TV-light values are supplied by `YurtVisualDirector`.
- No `ReflectionProbe` node exists in `Main.tscn` at this baseline, so `reflection_probe_path` is intentionally empty.
