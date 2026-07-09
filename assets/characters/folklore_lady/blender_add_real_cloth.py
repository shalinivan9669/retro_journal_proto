"""
Run inside Blender:
1) Put this file next to folklore_kazakh_seated_woman_cloth_blockout.glb
2) Blender > Scripting > Run Script
It imports the GLB, adds real Cloth modifiers to objects named cloth_*, adds collisions,
adds an oil-lamp point light, camera, and saves a .blend file.
"""
import bpy
import os
from mathutils import Vector

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
GLB_PATH = os.path.join(BASE_DIR, "folklore_kazakh_seated_woman_cloth_blockout.glb")
BLEND_OUT = os.path.join(BASE_DIR, "folklore_kazakh_seated_woman_REAL_CLOTH.blend")

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

bpy.ops.import_scene.gltf(filepath=GLB_PATH)

# Unit/scaling cleanup
bpy.context.scene.unit_settings.system = 'METRIC'

# Materials: make fabric visibly rough, veils transparent
for mat in bpy.data.materials:
    mat.use_nodes = True
    name = mat.name.lower()
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    if not bsdf:
        continue
    if 'veil' in name or 'glass' in name or 'tea' in name:
        mat.blend_method = 'BLEND'
        mat.use_screen_refraction = True
        mat.show_transparent_back = True
    if 'fabric' in name or 'rug' in name or 'veil' in name:
        if 'Roughness' in bsdf.inputs:
            bsdf.inputs['Roughness'].default_value = 0.88
    if 'gold' in name or 'silver' in name:
        if 'Metallic' in bsdf.inputs:
            bsdf.inputs['Metallic'].default_value = 1.0
        if 'Roughness' in bsdf.inputs:
            bsdf.inputs['Roughness'].default_value = 0.22

# Add collision to all solid body/environment pieces so cloth can fall on them
collision_keywords = [
    'collision', 'floor', 'wall', 'bench', 'arch', 'pillar', 'shoulder', 'neck', 'head',
    'crown', 'lamp', 'shelf', 'rug_base'
]
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH' and any(k in obj.name.lower() for k in collision_keywords):
        if not obj.modifiers.get('Collision'):
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.modifier_add(type='COLLISION')
            obj.select_set(False)

# Cloth settings for the robe and veils
for obj in bpy.context.scene.objects:
    if obj.type != 'MESH' or not obj.name.lower().startswith('cloth_'):
        continue

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    # Subdivide a bit to give the cloth enough vertices.
    sub = obj.modifiers.new(name='cloth_pre_subdivision', type='SUBSURF')
    sub.levels = 1
    sub.render_levels = 1

    # Pin top band of cloth so it stays attached to head/shoulders.
    vg = obj.vertex_groups.new(name='PIN_TOP')
    world_z = [(obj.matrix_world @ v.co).z for v in obj.data.vertices]
    max_z = max(world_z)
    min_z = min(world_z)
    height = max(max_z - min_z, 0.001)
    pin_indices = []
    for v in obj.data.vertices:
        wz = (obj.matrix_world @ v.co).z
        wx = (obj.matrix_world @ v.co).x
        # Pin the top 8% and the high side borders. This prevents veil collapse.
        if wz > max_z - height * 0.08:
            pin_indices.append(v.index)
        if 'veil' in obj.name.lower() and wz > max_z - height * 0.22 and abs(wx) > 0.32:
            pin_indices.append(v.index)
        if 'robe' in obj.name.lower() and wz > max_z - height * 0.18 and abs(wx) < 0.55:
            pin_indices.append(v.index)
    if pin_indices:
        vg.add(list(set(pin_indices)), 1.0, 'ADD')

    cloth = obj.modifiers.new(name='REAL_CLOTH_simulation', type='CLOTH')
    cloth.settings.vertex_group_mass = 'PIN_TOP'
    cloth.settings.quality = 8
    cloth.settings.mass = 0.18 if 'veil' in obj.name.lower() else 0.32
    cloth.settings.tension_stiffness = 12
    cloth.settings.compression_stiffness = 12
    cloth.settings.shear_stiffness = 6
    cloth.settings.bending_stiffness = 0.6 if 'veil' in obj.name.lower() else 1.5
    cloth.settings.air_damping = 1.0
    cloth.collision_settings.use_collision = True
    cloth.collision_settings.use_self_collision = True
    cloth.collision_settings.distance_min = 0.025
    cloth.collision_settings.self_distance_min = 0.015
    cloth.collision_settings.impulse_clamp = 1.0

    # Tiny thickness after cloth, so it is still visually fabric and not a paper plane.
    solid = obj.modifiers.new(name='fabric_visual_thickness_after_cloth', type='SOLIDIFY')
    solid.thickness = 0.008 if 'veil' in obj.name.lower() else 0.018
    solid.offset = 0

    obj.select_set(False)

# Lighting: only oil lamp. Strong warm point light at the flame.
bpy.ops.object.light_add(type='POINT', location=(-1.38, -0.18, 0.78))
lamp = bpy.context.object
lamp.name = 'ONLY_LIGHT_SOURCE_oil_lamp_fire'
lamp.data.color = (1.0, 0.48, 0.16)
lamp.data.energy = 620
lamp.data.shadow_soft_size = 2.1

# A very weak ambient so Blender viewport isn't pitch black. Lower to 0 for strict lamp-only render.
bpy.context.scene.world.color = (0.015, 0.010, 0.006)

# Camera: front view, portrait composition
bpy.ops.object.camera_add(location=(0, -5.2, 1.18), rotation=(1.36, 0, 0))
bpy.context.scene.camera = bpy.context.object
bpy.context.object.name = 'front_portrait_camera'

# Render settings
bpy.context.scene.render.engine = 'CYCLES'
bpy.context.scene.cycles.samples = 64
bpy.context.scene.view_settings.view_transform = 'Filmic'
bpy.context.scene.view_settings.look = 'Medium High Contrast'
bpy.context.scene.render.resolution_x = 1400
bpy.context.scene.render.resolution_y = 1800

# Set timeline frames for cloth settling
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 90

# Save .blend
bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
print('Saved:', BLEND_OUT)
