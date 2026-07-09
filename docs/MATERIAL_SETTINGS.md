# Suggested Godot Material Settings

## mat_sky_dome.tres
- Type: ShaderMaterial
- Shading Mode: Unshaded
- Source Panorama: res://assets/textures/sky/overcast_soil_puresky_16k.exr
- Source: Poly Haven Overcast Soil (Pure Sky), CC0
- Cull Mode: Disabled or Front
- Transparency: Disabled
- Collision: no collision on SkyDome

## mat_cloud_dark_ash_red.tres
- Type: StandardMaterial3D
- Shading Mode: Unshaded
- Albedo Texture: res://assets/textures/sky/cloud_dark_ash_red_alpha.png
- Transparency: Alpha
- Cull Mode: Disabled
- Depth Draw: Alpha-friendly / Prepass if needed
- Emission: optional dark red, energy 0.1–0.3

## mat_cloud_rose_ash_red.tres
- Type: StandardMaterial3D
- Shading Mode: Unshaded
- Albedo Texture: res://assets/textures/sky/cloud_rose_ash_red_alpha.png
- Transparency: Alpha
- Cull Mode: Disabled
- Emission: optional dusty red, energy 0.05–0.2

## mat_steppe_ground.tres
- Type: StandardMaterial3D
- Albedo Texture: res://assets/textures/ground/tex_steppe_dry_ground_1024.png
- Repeat: Enabled
- Roughness: 1.0
- Metallic: 0.0
- UV1 Scale: start with Vector3(40, 40, 1) for a 200x200 plane

## Flower materials
Keep flowers muted. Do not make RGB candy colors.
- Red: dark blood red, not pure red
- Yellow: dirty ochre
- White: cold off-white
- Grass: gray-green / dry yellow-green
