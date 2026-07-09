"""
Blender DEM megawall production notes.
This is not a one-click terrain importer because DEM source/export formats vary.
Use QGIS/OpenTopography first, export a normalized 16-bit heightmap, then use this as a starting script in Blender.

Target output passes for Godot:
- mountain_wall_day_16384x4096.png
- mountain_wall_night_16384x4096.png
- mountain_wall_alpha_16384x4096.png
- mountain_wall_depth_8192x2048.png
- snow_mask_8192x2048.png
- emission_mask_4096x1024.png
"""
import bpy
from mathutils import Vector

# Usage inside Blender:
# 1. File > New.
# 2. Put your exported DEM heightmap at //heightmap_16bit.png.
# 3. Run this script and replace material paths/textures.
# 4. Render with mist/depth passes enabled.

bpy.ops.object.delete()

# Create a displaced plane terrain.
bpy.ops.mesh.primitive_grid_add(x_subdivisions=512, y_subdivisions=512, size=1000, location=(0,0,0))
terrain = bpy.context.object
terrain.name = 'DEM_Mountain_Megawall_Terrain'

tex = bpy.data.textures.new('DEM_heightmap', type='IMAGE')
# tex.image = bpy.data.images.load('//heightmap_16bit.png')
mod = terrain.modifiers.new('DEM_Displace', 'DISPLACE')
mod.strength = 180.0
mod.texture = tex

# Camera telephoto look: compresses depth, makes mountains massive.
bpy.ops.object.camera_add(location=(0, -850, 120), rotation=(1.396, 0, 0))
cam = bpy.context.object
cam.data.lens = 120
cam.data.sensor_width = 32
bpy.context.scene.camera = cam

# Lighting: cold side sun plus cloudy world.
bpy.ops.object.light_add(type='SUN', location=(0, -300, 500))
sun = bpy.context.object
sun.name = 'Cold_Low_Sun_or_Moon'
sun.data.energy = 1.5
sun.rotation_euler = (0.9, 0.0, -0.65)

# Render settings.
bpy.context.scene.render.resolution_x = 16384
bpy.context.scene.render.resolution_y = 4096
bpy.context.scene.eevee.taa_render_samples = 64 if hasattr(bpy.context.scene, 'eevee') else 16
bpy.context.scene.view_settings.view_transform = 'Filmic'
bpy.context.scene.view_settings.look = 'Medium High Contrast'
bpy.context.scene.view_settings.exposure = 0
bpy.context.scene.view_settings.gamma = 1

print('DEM megawall scene scaffold ready. Add materials by slope/height, mist, and render passes.')
