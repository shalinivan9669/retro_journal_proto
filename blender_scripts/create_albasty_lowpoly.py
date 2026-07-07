"""
create_albasty_lowpoly.py
Procedural low-poly Albasty creature generator for Blender.

Run from the project root:
  blender --background --python blender_scripts/create_albasty_lowpoly.py

Output:
  assets/models/albasty_lowpoly.glb
  assets/models/albasty_lowpoly.blend
  assets/models/albasty_preview.png

Design goal:
  2.8m tall hunched female/yeti-like Kazakh steppe spirit.
  Long black root-like hair, beautiful half-hidden pale face, oversized arms,
  triangular feather/leaf cloak, red threads, amulets, golden diadem.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

# -----------------------------------------------------------------------------
# Paths / deterministic setup
# -----------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
OUT_DIR = PROJECT_ROOT / "assets" / "models"
SOURCE_OUT_DIR = PROJECT_ROOT / "blender_outputs"
OUT_DIR.mkdir(parents=True, exist_ok=True)
SOURCE_OUT_DIR.mkdir(parents=True, exist_ok=True)

GLB_PATH = OUT_DIR / "albasty_lowpoly.glb"
BLEND_PATH = SOURCE_OUT_DIR / "albasty_lowpoly.blend"
PREVIEW_PATH = OUT_DIR / "albasty_preview.png"

random.seed(42)

# Toggle if you want a human scale marker inside the exported file.
CREATE_SCALE_REFERENCE = False
CREATE_ARMATURE_REFERENCE = False
EXPORT_PREVIEW = True

# -----------------------------------------------------------------------------
# Scene utilities
# -----------------------------------------------------------------------------

def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in list(bpy.data.meshes):
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        if block.users == 0:
            bpy.data.materials.remove(block)


def set_units() -> None:
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0


def make_material(name: str, color: tuple[float, float, float, float], roughness: float = 0.75) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def make_metal_material(name: str, color: tuple[float, float, float, float], metallic: float = 0.7) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = 0.55
    return mat


def shade_flat(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_flat()
    obj.select_set(False)


def parent_to(obj: bpy.types.Object, parent: bpy.types.Object) -> bpy.types.Object:
    obj.parent = parent
    return obj


def orient_obj_z_to_vector(obj: bpy.types.Object, start: Vector, end: Vector) -> None:
    direction = end - start
    obj.location = (start + end) * 0.5
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()

# -----------------------------------------------------------------------------
# Primitive builders
# -----------------------------------------------------------------------------

def create_cone_between(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    r_start: float,
    r_end: float,
    vertices: int,
    mat: bpy.types.Material,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    s = Vector(start)
    e = Vector(end)
    length = max((e - s).length, 0.001)
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=r_start,
        radius2=r_end,
        depth=length,
        end_fill_type="TRIFAN",
        location=(0, 0, 0),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.data.materials.append(mat)
    orient_obj_z_to_vector(obj, s, e)
    shade_flat(obj)
    parent_to(obj, parent)
    return obj


def create_ico(
    name: str,
    loc: tuple[float, float, float],
    scale: tuple[float, float, float],
    mat: bpy.types.Material,
    parent: bpy.types.Object,
    subdivisions: int = 1,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.scale = scale
    obj.data.materials.append(mat)
    shade_flat(obj)
    parent_to(obj, parent)
    return obj


def create_cube(
    name: str,
    loc: tuple[float, float, float],
    scale: tuple[float, float, float],
    mat: bpy.types.Material,
    parent: bpy.types.Object,
    rot: tuple[float, float, float] = (0, 0, 0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = f"{name}_Mesh"
    obj.scale = scale
    obj.data.materials.append(mat)
    shade_flat(obj)
    parent_to(obj, parent)
    return obj


def create_triangle_panel(
    name: str,
    root: Vector,
    tip: Vector,
    width: float,
    mat: bpy.types.Material,
    parent: bpy.types.Object,
    lift: Vector = Vector((0, 0, 0)),
) -> bpy.types.Object:
    """Single triangular low-poly feather/leaf plate."""
    direction = tip - root
    if direction.length == 0:
        direction = Vector((0, 0, -1))
    # Width axis roughly perpendicular in XY; fallback stable.
    side = Vector((-direction.y, direction.x, 0.0))
    if side.length < 0.001:
        side = Vector((1, 0, 0))
    side.normalize()
    a = root + side * width * 0.5 + lift
    b = root - side * width * 0.5 + lift
    c = tip + lift
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata([tuple(a), tuple(b), tuple(c)], [], [(0, 1, 2)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    parent_to(obj, parent)
    return obj


def create_diamond_pendant(
    name: str,
    center: tuple[float, float, float],
    size: float,
    mat_outer: bpy.types.Material,
    mat_inner: bpy.types.Material,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    # Outer gold diamond: flattened cube rotated 45 degrees.
    obj = create_cube(
        f"{name}_GoldDiamond",
        center,
        (size, 0.014, size),
        mat_outer,
        parent,
        rot=(0, 0, math.radians(45)),
    )
    # Inner turquoise diamond, slightly in front.
    inner_loc = (center[0], center[1] - 0.016, center[2])
    create_cube(
        f"{name}_TurquoiseCore",
        inner_loc,
        (size * 0.52, 0.012, size * 0.52),
        mat_inner,
        parent,
        rot=(0, 0, math.radians(45)),
    )
    return obj

# -----------------------------------------------------------------------------
# Materials
# -----------------------------------------------------------------------------

def create_materials() -> dict[str, bpy.types.Material]:
    return {
        "hair_black": make_material("mat_hair_root_black", (0.015, 0.018, 0.018, 1.0)),
        "hair_dark": make_material("mat_dark_hair_facets", (0.035, 0.043, 0.044, 1.0)),
        "cloak_brown": make_material("mat_brown_dead_grass", (0.23, 0.16, 0.10, 1.0)),
        "cloak_copper": make_material("mat_copper_leaf", (0.42, 0.23, 0.10, 1.0)),
        "skin_pale": make_material("mat_pale_ash_skin", (0.63, 0.58, 0.51, 1.0)),
        "skin_shadow": make_material("mat_face_shadow", (0.18, 0.16, 0.15, 1.0)),
        "eye_dark": make_material("mat_black_eyes", (0.0, 0.0, 0.0, 1.0)),
        "gold": make_metal_material("mat_old_steppe_gold", (0.86, 0.55, 0.19, 1.0), 0.55),
        "turquoise": make_material("mat_turquoise_bead", (0.02, 0.48, 0.50, 1.0)),
        "deep_teal": make_material("mat_deep_teal_fabric", (0.02, 0.22, 0.24, 1.0)),
        "red_thread": make_material("mat_red_threads", (0.55, 0.045, 0.035, 1.0)),
        "bone": make_material("mat_bone_claws", (0.72, 0.67, 0.55, 1.0)),
        "stone": make_material("mat_stone_reference", (0.28, 0.29, 0.28, 1.0)),
    }

# -----------------------------------------------------------------------------
# Albasty body construction
# -----------------------------------------------------------------------------

def build_body(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    # Main hidden body: thin, slanted, hunched.
    create_cone_between(
        "Body_Hunched_Torso",
        (0.0, 0.02, 0.62),
        (0.0, -0.17, 2.02),
        0.30,
        0.44,
        7,
        mats["hair_dark"],
        root,
    )
    create_ico("Pelvis_Small", (0.0, 0.06, 0.72), (0.25, 0.18, 0.18), mats["hair_dark"], root, subdivisions=1)
    create_ico("Chest_Narrow", (0.0, -0.16, 1.88), (0.43, 0.24, 0.28), mats["hair_dark"], root, subdivisions=1)

    # Pale, beautiful but hidden female face.
    create_ico("Face_Beautiful_HalfHidden", (0.0, -0.38, 2.22), (0.17, 0.105, 0.23), mats["skin_pale"], root, subdivisions=2)
    create_ico("Chin_Pale", (0.0, -0.415, 2.05), (0.105, 0.055, 0.07), mats["skin_pale"], root, subdivisions=1)
    create_ico("Left_Dark_Eye", (-0.055, -0.475, 2.265), (0.018, 0.012, 0.012), mats["eye_dark"], root, subdivisions=1)
    create_ico("Right_Dark_Eye", (0.055, -0.475, 2.265), (0.018, 0.012, 0.012), mats["eye_dark"], root, subdivisions=1)
    create_cone_between("Nose_Sharp_Facet", (0, -0.485, 2.245), (0, -0.535, 2.16), 0.018, 0.006, 4, mats["skin_shadow"], root)

    # Long disproportionate arms: shoulders forward/down, hands near knees.
    arm_specs = [
        ("L", -1.0, (-0.36, -0.13, 1.92), (-0.58, -0.32, 1.25), (-0.70, -0.30, 0.67)),
        ("R", 1.0, (0.36, -0.13, 1.92), (0.56, -0.30, 1.19), (0.67, -0.26, 0.75)),
    ]
    for side, sign, shoulder, elbow, wrist in arm_specs:
        create_cone_between(f"{side}_UpperArm_TooLong", shoulder, elbow, 0.075, 0.050, 5, mats["skin_pale"], root)
        create_cone_between(f"{side}_Forearm_TooLong", elbow, wrist, 0.052, 0.038, 5, mats["skin_pale"], root)
        create_ico(f"{side}_Hand_Knuckle", wrist, (0.090, 0.045, 0.052), mats["skin_pale"], root, subdivisions=1)
        # Long fingers / claws.
        for i, spread in enumerate([-0.06, -0.025, 0.015, 0.055]):
            finger_start = Vector((wrist[0] + spread * sign, wrist[1] - 0.015, wrist[2] - 0.025))
            finger_end = finger_start + Vector((0.025 * sign + spread * 0.25, -0.055, -0.16 - 0.015 * i))
            create_cone_between(f"{side}_Finger_{i+1}", tuple(finger_start), tuple(finger_end), 0.018, 0.009, 4, mats["skin_pale"], root)
            claw_end = finger_end + Vector((0.014 * sign, -0.025, -0.055))
            create_cone_between(f"{side}_Claw_{i+1}", tuple(finger_end), tuple(claw_end), 0.011, 0.002, 4, mats["bone"], root)

    # Thin legs and bare feet under cloak.
    leg_specs = [
        ("L", -0.14),
        ("R", 0.14),
    ]
    for side, x in leg_specs:
        create_cone_between(f"{side}_Hidden_Thigh", (x, 0.035, 0.70), (x * 1.08, -0.02, 0.35), 0.06, 0.045, 5, mats["skin_shadow"], root)
        create_cone_between(f"{side}_Hidden_Shin", (x * 1.08, -0.02, 0.35), (x * 1.18, -0.11, 0.08), 0.045, 0.030, 5, mats["skin_pale"], root)
        create_ico(f"{side}_Bare_Foot", (x * 1.22, -0.20, 0.035), (0.105, 0.205, 0.038), mats["skin_pale"], root, subdivisions=1)
        for toe in [-0.055, -0.020, 0.020, 0.058]:
            create_cone_between(
                f"{side}_ToeClaw_{toe:+.2f}",
                (x * 1.22 + toe, -0.34, 0.045),
                (x * 1.22 + toe * 1.02, -0.41, 0.035),
                0.014,
                0.002,
                4,
                mats["bone"],
                root,
            )


def build_hair_and_cloak(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    # Hair mass / hood.
    create_ico("Hair_Mass_Above_Face", (0, -0.33, 2.33), (0.30, 0.19, 0.25), mats["hair_black"], root, subdivisions=1)
    create_ico("Back_Hair_Hump", (0, 0.01, 1.85), (0.60, 0.24, 0.88), mats["hair_black"], root, subdivisions=1)

    # Layered triangular feather/leaf plates. Keep them big and readable.
    cloak_mats = [mats["hair_black"], mats["hair_dark"], mats["cloak_brown"], mats["cloak_copper"], mats["deep_teal"]]
    count = 78
    for i in range(count):
        z_root = random.uniform(0.82, 2.35)
        side = random.choice([-1, 1])
        # Fan around sides/front/back; more on sides/back.
        angle = random.uniform(math.radians(35), math.radians(155))
        if side < 0:
            angle = -angle
        radius = random.uniform(0.24, 0.55) + max(0, 1.4 - z_root) * 0.09
        x = math.sin(angle) * radius
        y = -0.10 + math.cos(angle) * 0.18 + random.uniform(-0.04, 0.04)
        root_pos = Vector((x, y, z_root))
        length = random.uniform(0.34, 0.78)
        tip_pos = root_pos + Vector((side * random.uniform(0.04, 0.18), random.uniform(-0.05, 0.05), -length))
        width = random.uniform(0.075, 0.18)
        mat = random.choice(cloak_mats)
        create_triangle_panel(f"Hair_Cloak_Triangle_{i:02d}", root_pos, tip_pos, width, mat, root)

    # Long root-like black hair strands around face/head.
    branch_anchors = [
        (-0.18, -0.36, 2.48), (-0.05, -0.39, 2.50), (0.08, -0.39, 2.49),
        (0.22, -0.31, 2.43), (-0.25, -0.30, 2.42), (0.0, -0.42, 2.36),
    ]
    for idx, start in enumerate(branch_anchors):
        sign = -1 if start[0] < 0 else 1
        if abs(start[0]) < 0.01:
            sign = random.choice([-1, 1])
        mid = (start[0] + sign * random.uniform(0.08, 0.25), start[1] - random.uniform(0.04, 0.10), start[2] - random.uniform(0.22, 0.45))
        end = (mid[0] + sign * random.uniform(0.10, 0.32), mid[1] - random.uniform(0.02, 0.08), mid[2] - random.uniform(0.20, 0.55))
        create_cone_between(f"RootHair_{idx:02d}_A", start, mid, 0.018, 0.011, 4, mats["hair_black"], root)
        create_cone_between(f"RootHair_{idx:02d}_B", mid, end, 0.011, 0.004, 4, mats["hair_black"], root)


def build_diadem_and_amulets(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    gold = mats["gold"]
    turquoise = mats["turquoise"]
    red = mats["red_thread"]
    bone = mats["bone"]

    # Golden angular diadem across forehead and branch horns.
    create_cone_between("Diadem_Front_Band", (-0.20, -0.52, 2.39), (0.20, -0.52, 2.39), 0.018, 0.018, 4, gold, root)
    create_diamond_pendant("Diadem_Center", (0.0, -0.545, 2.43), 0.070, gold, turquoise, root)
    for side in [-1, 1]:
        create_cone_between(f"Diadem_Branch_{side}_Main", (0.08 * side, -0.51, 2.42), (0.36 * side, -0.42, 2.70), 0.018, 0.006, 4, gold, root)
        create_cone_between(f"Diadem_Branch_{side}_Outer", (0.18 * side, -0.48, 2.48), (0.46 * side, -0.36, 2.55), 0.014, 0.004, 4, gold, root)
        create_cone_between(f"Diadem_Branch_{side}_Inner", (0.20 * side, -0.47, 2.50), (0.26 * side, -0.42, 2.76), 0.014, 0.004, 4, gold, root)
        create_ico(f"Diadem_Tip_Bead_{side}", (0.36 * side, -0.42, 2.70), (0.025, 0.025, 0.025), gold, root, subdivisions=1)

    # Dangling hair ornaments from head.
    for side in [-1, 1]:
        for strand in range(3):
            x = side * (0.07 + strand * 0.07)
            top = Vector((x, -0.515, 2.34 - strand * 0.03))
            prev = top
            for bead_i in range(5):
                z = 2.22 - bead_i * 0.12 - strand * 0.04
                p = Vector((x + side * 0.025 * math.sin(bead_i), -0.52, z))
                create_cone_between(f"HairOrn_String_{side}_{strand}_{bead_i}", tuple(prev), tuple(p), 0.004, 0.004, 4, gold, root)
                mat = turquoise if bead_i % 2 else gold
                create_ico(f"HairOrn_Bead_{side}_{strand}_{bead_i}", tuple(p), (0.022, 0.022, 0.022), mat, root, subdivisions=1)
                prev = p
            # red tassel triangle.
            create_triangle_panel(f"HairOrn_RedTassel_{side}_{strand}", prev, prev + Vector((side * 0.015, -0.01, -0.14)), 0.035, red, root)

    # Chest amulet strings and pendants.
    chest_anchor_l = Vector((-0.20, -0.44, 1.95))
    chest_anchor_r = Vector((0.20, -0.44, 1.95))
    chest_mid = Vector((0.0, -0.52, 1.30))
    create_cone_between("Chest_String_Left", tuple(chest_anchor_l), tuple(chest_mid), 0.006, 0.006, 4, gold, root)
    create_cone_between("Chest_String_Right", tuple(chest_anchor_r), tuple(chest_mid), 0.006, 0.006, 4, gold, root)
    create_diamond_pendant("Chest_Main_Amulet", tuple(chest_mid), 0.095, gold, turquoise, root)

    for i in range(7):
        t = i / 6.0
        p_left = chest_anchor_l.lerp(chest_mid, t)
        p_right = chest_anchor_r.lerp(chest_mid, t)
        create_ico(f"Chest_Bead_L_{i}", tuple(p_left), (0.020, 0.020, 0.020), turquoise if i % 2 else gold, root, subdivisions=1)
        create_ico(f"Chest_Bead_R_{i}", tuple(p_right), (0.020, 0.020, 0.020), turquoise if i % 2 else gold, root, subdivisions=1)

    # Red threads over front.
    for idx, x in enumerate([-0.11, 0.0, 0.13]):
        top = Vector((x, -0.51, 1.80))
        bottom = Vector((x + random.uniform(-0.05, 0.05), -0.53, 0.95))
        create_cone_between(f"Red_Thread_{idx}", tuple(top), tuple(bottom), 0.009, 0.005, 4, red, root)
        create_triangle_panel(f"Red_Tassel_{idx}", bottom, bottom + Vector((0.02, -0.01, -0.18)), 0.055, red, root)

    # Bone/charm fragments on belt line.
    for idx, x in enumerate([-0.18, -0.06, 0.08, 0.21]):
        create_cone_between(f"Bone_Charm_{idx}", (x, -0.52, 1.12), (x + 0.015, -0.54, 0.98), 0.016, 0.006, 4, bone, root)


def build_armature_reference(root: bpy.types.Object) -> None:
    if not CREATE_ARMATURE_REFERENCE:
        return
    arm_data = bpy.data.armatures.new("Albasty_Armature_Reference_Data")
    arm_obj = bpy.data.objects.new("Albasty_Armature_Reference", arm_data)
    bpy.context.collection.objects.link(arm_obj)
    arm_obj.parent = root
    arm_obj.show_in_front = True
    arm_data.display_type = "STICK"

    bpy.context.view_layer.objects.active = arm_obj
    arm_obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name: str, head: tuple[float, float, float], tail: tuple[float, float, float]) -> None:
        b = arm_data.edit_bones.new(name)
        b.head = head
        b.tail = tail
        b.roll = 0

    bone("pelvis", (0, 0.00, 0.70), (0, -0.04, 1.05))
    bone("spine_hunched", (0, -0.04, 1.05), (0, -0.16, 1.80))
    bone("neck", (0, -0.16, 1.80), (0, -0.34, 2.10))
    bone("head", (0, -0.34, 2.10), (0, -0.38, 2.42))
    bone("arm_L_upper", (-0.34, -0.13, 1.90), (-0.57, -0.32, 1.25))
    bone("arm_L_lower", (-0.57, -0.32, 1.25), (-0.70, -0.30, 0.67))
    bone("arm_R_upper", (0.34, -0.13, 1.90), (0.56, -0.30, 1.19))
    bone("arm_R_lower", (0.56, -0.30, 1.19), (0.67, -0.26, 0.75))
    bone("leg_L", (-0.14, 0.03, 0.70), (-0.17, -0.20, 0.05))
    bone("leg_R", (0.14, 0.03, 0.70), (0.17, -0.20, 0.05))

    bpy.ops.object.mode_set(mode="OBJECT")
    arm_obj.select_set(False)


def build_scale_reference(root: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    if not CREATE_SCALE_REFERENCE:
        return
    # 1.8m human marker for checking scale. Disabled by default.
    create_cone_between("Scale_Reference_1_8m", (-1.15, 0.0, 0.0), (-1.15, 0.0, 1.8), 0.12, 0.10, 8, mats["stone"], root)


def add_metadata(root: bpy.types.Object) -> None:
    root["asset_name"] = "Albasty Low-Poly"
    root["height_meters"] = 2.8
    root["description"] = "Hunched Kazakh steppe spirit, female/yeti silhouette, long root-like hair, amulets, red threads, golden diadem."
    root["gameplay_note"] = "Designed for rare appearances near powerline towers and horse areas."

# -----------------------------------------------------------------------------
# Lighting / preview / export
# -----------------------------------------------------------------------------

def setup_camera_and_light() -> None:
    bpy.ops.object.light_add(type="SUN", location=(0, -3, 6))
    sun = bpy.context.object
    sun.name = "Preview_Sun"
    sun.data.energy = 2.2
    sun.rotation_euler = (math.radians(45), 0, math.radians(15))

    bpy.ops.object.light_add(type="AREA", location=(0, -3.5, 3.0))
    area = bpy.context.object
    area.name = "Preview_Softbox"
    area.data.energy = 400
    area.data.size = 4

    bpy.ops.object.camera_add(location=(0.0, -5.0, 1.65), rotation=(math.radians(77), 0, 0))
    cam = bpy.context.object
    bpy.context.scene.camera = cam
    cam.name = "Preview_Camera"
    cam.data.lens = 35


def save_preview() -> None:
    if not EXPORT_PREVIEW:
        return
    bpy.context.scene.render.resolution_x = 1200
    bpy.context.scene.render.resolution_y = 1600
    bpy.context.scene.eevee.taa_render_samples = 32 if hasattr(bpy.context.scene, "eevee") else 16
    bpy.context.scene.render.filepath = str(PREVIEW_PATH)
    try:
        bpy.ops.render.render(write_still=True)
    except Exception as exc:
        print(f"[WARN] Preview render skipped: {exc}")


def export_files() -> None:
    # Put all assets at scene origin. Origin is ground center by construction.
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        export_yup=True,
        use_selection=False,
        export_apply=True,
        export_materials="EXPORT",
        export_animations=True,
    )

    print(f"[OK] Saved Blender file: {BLEND_PATH}")
    print(f"[OK] Exported GLB: {GLB_PATH}")
    if EXPORT_PREVIEW:
        print(f"[OK] Preview target: {PREVIEW_PATH}")


def main() -> None:
    clear_scene()
    set_units()

    mats = create_materials()

    root = bpy.data.objects.new("Albasty_Root", None)
    bpy.context.collection.objects.link(root)
    root.location = (0, 0, 0)

    build_body(root, mats)
    build_hair_and_cloak(root, mats)
    build_diadem_and_amulets(root, mats)
    build_armature_reference(root)
    build_scale_reference(root, mats)
    add_metadata(root)
    setup_camera_and_light()

    # Ensure model points roughly toward -Y, Godot-friendly ground origin at (0,0,0).
    bpy.context.view_layer.objects.active = root
    export_files()
    save_preview()


if __name__ == "__main__":
    main()
