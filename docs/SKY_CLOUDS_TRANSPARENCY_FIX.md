# Sky Clouds Transparency Fix

The visible rectangular cloud cards were caused by opaque source PNGs. The new ChatGPT cloud images looked transparent in the image viewer because they contained a checkerboard pattern, but their actual alpha channel was fully opaque (`alpha=255`).

The runtime cloud system now uses cleaned textures only:

`res://assets/textures/sky/clouds_runtime_clean/`

## Runtime Cloud PNGs

- `cloud_01.png`
- `cloud_02.png`
- `cloud_03.png`
- `cloud_04.png`
- `cloud_05.png`
- `cloud_06.png`
- `cloud_07.png`
- `cloud_08.png`
- `cloud_09.png`
- `cloud_10.png`
- `cloud_11.png`
- `cloud_12.png`
- `cloud_13.png`

All 13 files have transparent borders and real alpha in the cloud shape.

## Source Mapping

- `cloud_01.png` <- `ChatGPT Image Jul 7, 2026, 05_20_57 AM (1).png`
- `cloud_02.png` <- `ChatGPT Image Jul 7, 2026, 05_20_57 AM (2) — копия.png`
- `cloud_03.png` <- `ChatGPT Image Jul 7, 2026, 06_39_43 AM (1) — копия.png`
- `cloud_04.png` <- `ChatGPT Image Jul 7, 2026, 06_39_43 AM (1).png`
- `cloud_05.png` <- `ChatGPT Image Jul 7, 2026, 06_39_43 AM (2).png`
- `cloud_06.png` <- `ChatGPT Image Jul 7, 2026, 06_39_44 AM (3) — копия.png`
- `cloud_07.png` <- `ChatGPT Image Jul 7, 2026, 06_39_44 AM (3).png`
- `cloud_08.png` <- `ChatGPT Image Jul 7, 2026, 06_39_45 AM (4).png`
- `cloud_09.png` <- `ChatGPT Image Jul 7, 2026, 06_39_46 AM (5).png`
- `cloud_10.png` <- `ChatGPT Image Jul 7, 2026, 06_39_46 AM (6) — копия.png`
- `cloud_11.png` <- `ChatGPT Image Jul 7, 2026, 06_39_46 AM (6).png`
- `cloud_12.png` <- `cloud_dark_ash_red_alpha.png`
- `cloud_13.png` <- `cloud_rose_ash_red_alpha.png`

## Ignored Files

The cloud scanner ignores:

- `*.import`
- `*.exr`
- names containing `checkerboard`
- names containing `source`
- names containing `preview`
- names containing `tonemap`
- everything outside `clouds_runtime_clean/`

The original source PNG files remain in `res://assets/textures/sky/` for reference, but the runtime does not render them directly.

## Runtime Node Type

Clouds use runtime `MeshInstance3D` nodes with `PlaneMesh` geometry. Materials are created in `res://scripts/sky_clouds_controller.gd`.

Material settings:

- `albedo_texture` = cleaned PNG
- `albedo_color` = `Color.WHITE`
- `shading_mode` = unshaded
- `transparency` = alpha
- `cull_mode` = disabled
- shadows off on each cloud mesh

This prevents any global tinted card from appearing; only the PNG alpha controls cloud visibility.

## Where To Tune

Edit `res://scripts/sky_clouds_controller.gd`.

- Speed: `speed_multiplier` and per-layer `velocity` values in `_far_layout()`, `_mid_layout()`, `_accent_layout()`
- Chaotic drift: `chaos_multiplier`, `_drift_axis()`, and per-cloud drift values created in `_create_cloud()`
- Count: add/remove cleaned PNG files in `res://assets/textures/sky/clouds_runtime_clean/`
- Size: `density_multiplier` and per-cloud `size` values in layout functions
- Height: `cloud_height_offset` and per-cloud `position.y`
- Transparency: edit the cleaned PNG alpha, not material alpha

## If Rectangular Cards Return

1. Check that `CLOUD_TEXTURE_DIR` points to `res://assets/textures/sky/clouds_runtime_clean`.
2. Check the suspect PNG edge alpha. Edge pixels should be alpha 0.
3. Do not use checkerboard/source/preview images as runtime textures.
4. Keep material `albedo_color = Color.WHITE`; do not use semi-transparent albedo color to fade the whole plane.
5. Regenerate a cleaned PNG if a source image contains baked-in checkerboard or haze.
