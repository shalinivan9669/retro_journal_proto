# Visual Shader Stage 1 Report

## Added Files

- `shaders/devices/device_screen_emission.gdshader`
- `shaders/postprocess/glitch_double_vision_soft.gdshader`
- `shaders/fog/sandstorm_fog_soft.gdshader`
- `shaders/fog/industrial_smoke_minimal.gdshader`
- `shaders/sky/panoramic_cloud_sky_blood.gdshader`
- `shaders/vfx/light_flare_ring_minimal.gdshader`
- `shaders/characters/albasy_waving_cloth_safe.gdshader`
- `materials/devices/mat_tv_screen_glow.tres`
- `materials/devices/mat_radio_display_glow.tres`
- `materials/devices/mat_phone_screen_glow.tres`
- `materials/postprocess/mat_glitch_double_vision_soft.tres`
- `materials/fog/mat_sandstorm_fog_soft.tres`
- `materials/fog/mat_industrial_smoke.tres`
- `materials/sky/mat_panoramic_cloud_sky_blood.tres`
- `materials/vfx/mat_light_flare_ring.tres`
- `materials/characters/mat_albasy_waving_cloth.tres`
- `scripts/visuals/retro_visuals_runtime.gd`
- `scripts/visuals/blood_spray_toggle.gd`
- `scripts/visuals/sky_lightning_controller.gd`
- `scripts/visuals/flare_billboard_to_camera.gd`
- `scripts/ui/phone_overlay.gd`
- `scenes/visuals/VisualEffectsRuntime.tscn`
- `scenes/visuals/OutdoorSandstormFogVolume.tscn`
- `scenes/visuals/IndustrialSmokeFogVolume.tscn`
- `scenes/visuals/BasementFlareRing.tscn`
- `scenes/visuals/BloodSprayPlaceholder.tscn`
- `scenes/ui/PhoneOverlay.tscn`
- `tools/install_visual_runtime_editor.gd`
- prepared visual docs from the archive.

## Changed Scenes

- `scenes/Main.tscn`
  - Added `VisualEffectsRuntime`.
  - Added `PhoneOverlay`.
  - Added `BloodSprayPlaceholder` outside and left of the yurt entrance.
- `scenes/levels/UndergroundSteppe.tscn`
  - Added one `BasementFlareRing` near the entry/return hatch area.

## VisualEffectsRuntime

`VisualEffectsRuntime` is connected as a root child in `Main.tscn`.

It searches the current scene recursively for:

- `WorldEnvironment`
- `InteractableTV`
- `RadioOnBox`
- active `Camera3D`

The runtime was adjusted for Godot 4.7 typed GDScript and deferred FogVolume insertion.

## Implemented Effects

- TV keeps its existing `VideoStreamPlayer` screen material so channel video remains visible.
- TV gets a small cold cyan/green local `OmniLight3D` and participates in glitch proximity.
- Radio display gets the prepared amber emission material at runtime.
- Radio gets a small amber local `OmniLight3D`.
- TV and radio are added to `glitch_device`.
- A fullscreen soft glitch overlay appears near TV/radio and hides when the player moves away.
- `WorldEnvironment` is tuned darker with weak glow, lower ambient, dusty fog, reduced saturation, and slightly higher contrast.
- Outdoor sandstorm/fog is enabled near the yurt entrance with limited size.
- One basement flare ring is connected in `UndergroundSteppe.tscn`.
- Blood spray placeholder is connected with red particles, `E` interaction, 30 second stop duration, and automatic restart.
- Phone overlay is connected. Press `1` to show/hide it. Movement is not blocked. Pressing another action key or mouse button hides it.

## Prepared But Not Connected

- Industrial smoke scene/material/shader are present, but not connected to arbitrary locations. Use them only after final distant chimney or industrial meshes exist.
- Panoramic blood sky material and lightning controller are present, but not enabled by default because the project already has an active sky/cloud system.
- ALBASY waving cloth material is present, but not applied because no safe separate cloth/hair strip mesh was identified.

## Skipped

- Fullscreen outline/posterization/dithering was not added at stage 1 because it can damage the whole bleak image.
- Basement ORM/vertex-color material blending was not applied because generated basement meshes do not expose a safe vertex-color workflow.

## How To Disable Visual Runtime

Remove or disable the `VisualEffectsRuntime` node in `scenes/Main.tscn`.

This removes runtime TV/radio emission assignment, local lights, glitch overlay, world environment tuning, and outdoor FogVolume insertion.

The phone overlay and blood placeholder are separate scene nodes and can be disabled independently in `Main.tscn`.

## FPS Notes

Potentially heavier effects:

- fullscreen glitch overlay, only active near devices;
- `FogVolume` outside the yurt;
- `GPUParticles3D` blood placeholder.

All are intentionally small or conditional for stage 1.

## Stage 2 Needs

- Final distant chimney or industrial meshes before enabling smoke.
- Separate ALBASY cloth/hair strip meshes before applying waving cloth.
- Final blood splat texture or cone mesh for better blood spray quality.
- Basement vertex colors or authored PBR/ORM textures before deeper concrete/decay material blending.
