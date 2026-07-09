import math
import os
import random
import zipfile
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ---------------- Materials ----------------

def mat(name, color, metallic=0.0, roughness=0.55, alpha_mode=None, double_sided=False, emissive=None):
    kwargs = dict(
        name=name,
        baseColorFactor=color,
        metallicFactor=metallic,
        roughnessFactor=roughness,
        doubleSided=double_sided,
    )
    if alpha_mode:
        kwargs['alphaMode'] = alpha_mode
    if emissive:
        kwargs['emissiveFactor'] = emissive
    return PBRMaterial(**kwargs)

MAT_SKIN = mat('warm_olive_skin', [0.70, 0.48, 0.34, 1.0], 0.0, 0.62)
MAT_LIP = mat('muted_dark_rose_lips', [0.34, 0.13, 0.11, 1.0], 0.0, 0.45)
MAT_HAIR = mat('deep_black_hair', [0.006, 0.005, 0.004, 1.0], 0.0, 0.35)
MAT_EYE = mat('dark_brown_eye', [0.025, 0.014, 0.008, 1.0], 0.0, 0.18)
MAT_RED_FABRIC = mat('deep_red_woven_fabric', [0.38, 0.035, 0.02, 1.0], 0.0, 0.83, double_sided=True)
MAT_RED_VEIL = mat('translucent_deep_red_veil_fabric', [0.55, 0.04, 0.025, 0.74], 0.0, 0.78, alpha_mode='BLEND', double_sided=True)
MAT_BLACK_VEIL = mat('translucent_black_back_veil_fabric', [0.01, 0.006, 0.004, 0.42], 0.0, 0.7, alpha_mode='BLEND', double_sided=True)
MAT_GOLD = mat('separate_bright_gold_metal', [1.0, 0.63, 0.13, 1.0], 1.0, 0.22)
MAT_OLD_GOLD = mat('aged_dark_gold_metal', [0.68, 0.42, 0.12, 1.0], 1.0, 0.36)
MAT_SILVER = mat('separate_cool_silver_metal', [0.82, 0.86, 0.88, 1.0], 1.0, 0.20)
MAT_RUBY = mat('ruby_red_gemstones', [0.55, 0.02, 0.03, 1.0], 0.0, 0.12)
MAT_EMERALD = mat('emerald_green_gemstones', [0.02, 0.38, 0.20, 1.0], 0.0, 0.13)
MAT_PLASTER = mat('warm_cracked_clay_plaster', [0.55, 0.37, 0.22, 1.0], 0.0, 0.9)
MAT_RUG = mat('dark_red_afghan_style_rug', [0.28, 0.035, 0.02, 1.0], 0.0, 0.86)
MAT_RUG_GOLD = mat('rug_faded_gold_pattern', [0.72, 0.48, 0.19, 1.0], 0.0, 0.85)
MAT_GLASS = mat('old_clear_glass', [0.7, 0.8, 0.78, 0.28], 0.0, 0.05, alpha_mode='BLEND', double_sided=True)
MAT_TEA = mat('hibiscus_tea_deep_amber_red', [0.55, 0.10, 0.03, 0.65], 0.0, 0.2, alpha_mode='BLEND', double_sided=True)
MAT_FLAME = mat('oil_lamp_fire_emissive', [1.0, 0.36, 0.05, 1.0], 0.0, 0.15, emissive=[1.0,0.45,0.08])
MAT_PIPE = mat('dark_wood_tobacco_pipe_in_background', [0.16, 0.075, 0.03, 1.0], 0.0, 0.42)

scene = trimesh.Scene()

# ---------------- Utilities ----------------

def add(mesh, name, material=None, transform=None):
    mesh = mesh.copy()
    mesh.metadata['name'] = name
    mesh.visual.material = material if material else mesh.visual.material
    scene.add_geometry(mesh, node_name=name, geom_name=name, transform=transform)
    return mesh

def T(loc=(0,0,0), scale=(1,1,1), rot=(0,0,0)):
    M = np.eye(4)
    rx, ry, rz = rot
    def Rx(a):
        c,s=math.cos(a),math.sin(a); return np.array([[1,0,0,0],[0,c,-s,0],[0,s,c,0],[0,0,0,1]])
    def Ry(a):
        c,s=math.cos(a),math.sin(a); return np.array([[c,0,s,0],[0,1,0,0],[-s,0,c,0],[0,0,0,1]])
    def Rz(a):
        c,s=math.cos(a),math.sin(a); return np.array([[c,-s,0,0],[s,c,0,0],[0,0,1,0],[0,0,0,1]])
    S = np.diag([scale[0], scale[1], scale[2], 1])
    Tr = np.eye(4); Tr[:3,3] = np.array(loc)
    return Tr @ Rz(rz) @ Ry(ry) @ Rx(rx) @ S

def align_z_to_vec(vec):
    vec = np.asarray(vec, dtype=float)
    L = np.linalg.norm(vec)
    if L < 1e-8:
        return np.eye(4)
    v = vec/L
    z = np.array([0.0,0.0,1.0])
    if np.allclose(v,z):
        return np.eye(4)
    if np.allclose(v,-z):
        return T(rot=(math.pi,0,0))
    axis = np.cross(z,v); axis = axis/np.linalg.norm(axis)
    angle = math.acos(np.clip(np.dot(z,v), -1, 1))
    K = np.array([[0,-axis[2],axis[1]],[axis[2],0,-axis[0]],[-axis[1],axis[0],0]])
    R3 = np.eye(3)+math.sin(angle)*K+(1-math.cos(angle))*(K@K)
    M=np.eye(4); M[:3,:3]=R3
    return M

def cyl_between(name, p1, p2, radius, material, sections=16):
    p1=np.array(p1,float); p2=np.array(p2,float); v=p2-p1; L=np.linalg.norm(v)
    mesh=trimesh.creation.cylinder(radius=radius, height=L, sections=sections)
    M=align_z_to_vec(v); M[:3,3]=(p1+p2)/2
    return add(mesh, name, material, M)

def sphere(name, loc, scale, material, subdivisions=2):
    mesh = trimesh.creation.icosphere(subdivisions=subdivisions, radius=1.0)
    return add(mesh, name, material, T(loc=loc, scale=scale))

def box(name, loc, extents, material, rot=(0,0,0)):
    mesh = trimesh.creation.box(extents=extents)
    return add(mesh, name, material, T(loc=loc, rot=rot))

def cone(name, loc, radius, height, material, sections=24, rot=(0,0,0)):
    mesh = trimesh.creation.cone(radius=radius, height=height, sections=sections)
    return add(mesh, name, material, T(loc=loc, rot=rot))

def torus_mesh(R=1.0, r=0.1, n=64, m=12):
    verts=[]; faces=[]
    for i in range(n):
        u=2*math.pi*i/n
        for j in range(m):
            v=2*math.pi*j/m
            verts.append([(R+r*math.cos(v))*math.cos(u), (R+r*math.cos(v))*math.sin(u), r*math.sin(v)])
    for i in range(n):
        for j in range(m):
            faces.append([i*m+j, ((i+1)%n)*m+j, ((i+1)%n)*m+(j+1)%m])
            faces.append([i*m+j, ((i+1)%n)*m+(j+1)%m, i*m+(j+1)%m])
    return trimesh.Trimesh(vertices=np.array(verts), faces=np.array(faces), process=True)

def torus(name, loc, R, r, material, scale=(1,1,1), rot=(0,0,0), n=64, m=10):
    return add(torus_mesh(R,r,n,m), name, material, T(loc=loc, scale=scale, rot=rot))

# ---------------- Environment: sitting niche ----------------
# floor and walls
box('stone_floor_base', (0,0.55,-0.72), (4.5,3.6,0.12), MAT_PLASTER)
box('back_plaster_wall_inside_niche', (0,1.82,0.65), (3.2,0.18,3.1), MAT_PLASTER)
box('left_plaster_wall', (-2.15,0.45,0.65), (0.22,3.2,3.2), MAT_PLASTER)
box('right_plaster_wall', (2.15,0.45,0.65), (0.22,3.2,3.2), MAT_PLASTER)
box('low_back_bench_plaster', (0,1.15,-0.25), (3.7,0.75,0.75), MAT_PLASTER)
# arch blocks around niche
for i in range(13):
    a = math.pi * i / 12
    x = 1.35*math.cos(a)
    z = 1.0 + 1.05*math.sin(a)
    rotz = a - math.pi/2
    box(f'rough_arch_block_{i:02d}', (x,0.05,z), (0.40,0.28,0.22), MAT_PLASTER, rot=(0,0,rotz))
box('left_arch_pillar', (-1.55,0.05,0.15), (0.42,0.28,1.75), MAT_PLASTER)
box('right_arch_pillar', (1.55,0.05,0.15), (0.42,0.28,1.75), MAT_PLASTER)
# cracks as dark thin lines
MAT_CRACK = mat('dark_plaster_cracks', [0.08,0.045,0.02,1], 0, 0.9)
random.seed(4)
for i in range(26):
    x = random.uniform(-1.7, 1.7); z = random.uniform(0.3, 2.0)
    length = random.uniform(0.08,0.25)
    cyl_between(f'irregular_wall_crack_{i:02d}', (x,0.005,z), (x+random.uniform(-.08,.08),0.005,z+length), 0.006, MAT_CRACK, 6)
# back hanging rug in niche
box('back_wall_dark_patterned_rug_base', (0,1.70,0.82), (2.20,0.035,1.45), MAT_RUG)
for i,x in enumerate(np.linspace(-0.92,0.92,7)):
    box(f'back_rug_vertical_gold_line_{i}', (x,1.675,0.82), (0.025,0.02,1.30), MAT_RUG_GOLD)
for i,z in enumerate(np.linspace(0.2,1.42,5)):
    box(f'back_rug_horizontal_gold_line_{i}', (0,1.67,z), (2.0,0.02,0.025), MAT_RUG_GOLD)
# sitting rug on floor
box('floor_afghan_carpet_base', (0,-0.10,-0.63), (4.1,2.65,0.035), MAT_RUG)
for i,x in enumerate(np.linspace(-1.9,1.9,9)):
    box(f'floor_carpet_gold_stripe_x_{i}', (x,-0.10,-0.60), (0.03,2.45,0.01), MAT_RUG_GOLD)
for i,y in enumerate(np.linspace(-1.25,1.05,7)):
    box(f'floor_carpet_gold_stripe_y_{i}', (0,y,-0.595), (3.8,0.025,0.01), MAT_RUG_GOLD)
for i in range(30):
    box(f'floor_rug_small_dark_diamond_{i}', (random.uniform(-1.8,1.8), random.uniform(-1.1,1.05), -0.585), (0.08,0.012,0.08), MAT_OLD_GOLD, rot=(0,0,math.pi/4))

# ---------------- Character body/head ----------------
# lower body hidden by cloth
sphere('body_under_fabric_simple_torso_collision', (0,-0.25,0.82), (0.38,0.20,0.72), MAT_SKIN, 2)
sphere('left_hidden_knee_under_robe_collision', (-0.42,-0.48,-0.16), (0.22,0.18,0.20), MAT_SKIN, 1)
sphere('right_hidden_knee_under_robe_collision', (0.44,-0.48,-0.20), (0.22,0.18,0.20), MAT_SKIN, 1)
# neck, collarbone, shoulders
cyl_between('long_thin_neck_collision', (0,-0.24,1.15), (0,-0.24,1.62), 0.13, MAT_SKIN, 32)
box('sharp_collarbone_suggestion', (0,-0.42,1.15), (0.95,0.035,0.035), MAT_SKIN)
sphere('left_shoulder_skin', (-0.55,-0.25,0.98), (0.28,0.19,0.16), MAT_SKIN, 2)
sphere('right_shoulder_skin', (0.55,-0.25,0.98), (0.28,0.19,0.16), MAT_SKIN, 2)
# custom long chiseled head

def chiseled_head_mesh():
    levels = [
        (-1.00, 0.12, 0.105),
        (-0.78, 0.19, 0.135),
        (-0.56, 0.28, 0.165),
        (-0.24, 0.38, 0.205),
        (0.08, 0.36, 0.220),
        (0.38, 0.33, 0.215),
        (0.72, 0.29, 0.190),
        (0.98, 0.17, 0.125),
    ]
    n=24; verts=[]; faces=[]
    for z,w,d in levels:
        for i in range(n):
            th = 2*math.pi*i/n
            # flatten the lower face and subtly carve temples
            x = w*math.cos(th)
            y = d*math.sin(th)
            if abs(th-math.pi/2) < 0.25 or abs(th-3*math.pi/2)<0.25:
                pass
            verts.append([x,y,z])
    for li in range(len(levels)-1):
        for i in range(n):
            faces.append([li*n+i, li*n+(i+1)%n, (li+1)*n+(i+1)%n])
            faces.append([li*n+i, (li+1)*n+(i+1)%n, (li+1)*n+i])
    # triangular caps
    bottom_center = len(verts); verts.append([0,0,levels[0][0]])
    top_center = len(verts); verts.append([0,0,levels[-1][0]])
    for i in range(n):
        faces.append([bottom_center, (i+1)%n, i])
        faces.append([top_center, (len(levels)-1)*n+i, (len(levels)-1)*n+(i+1)%n])
    return trimesh.Trimesh(vertices=np.array(verts), faces=np.array(faces), process=True)
head = chiseled_head_mesh()
add(head, 'sharp_long_oval_face_collision', MAT_SKIN, T(loc=(0,-0.27,1.93), scale=(1,0.96,0.56), rot=(0,0,0)))
# facial features: eyes brows nose lips
sphere('left_almond_eye_dark', (-0.135,-0.475,2.05), (0.085,0.012,0.025), MAT_EYE, 2)
sphere('right_almond_eye_dark', (0.135,-0.475,2.05), (0.085,0.012,0.025), MAT_EYE, 2)
cyl_between('left_thick_high_brow_rock_cut', (-0.27,-0.485,2.20), (-0.055,-0.485,2.22), 0.018, MAT_HAIR, 12)
cyl_between('right_thick_high_brow_rock_cut', (0.055,-0.485,2.22), (0.27,-0.485,2.20), 0.018, MAT_HAIR, 12)
# brow vertical rough hairs
for i,x in enumerate(np.linspace(-0.22,-0.08,6)):
    cyl_between(f'left_brow_short_hair_{i}', (x,-0.493,2.185), (x+0.012,-0.493,2.235), 0.006, MAT_HAIR, 6)
for i,x in enumerate(np.linspace(0.08,0.22,6)):
    cyl_between(f'right_brow_short_hair_{i}', (x,-0.493,2.235), (x+0.012,-0.493,2.185), 0.006, MAT_HAIR, 6)
# nose bridge and thin nostril wings
cyl_between('long_narrow_nose_bridge', (0,-0.50,2.08), (0,-0.56,1.86), 0.025, MAT_SKIN, 12)
sphere('narrow_nose_tip', (0,-0.575,1.84), (0.055,0.035,0.035), MAT_SKIN, 2)
sphere('left_thin_nose_wing', (-0.04,-0.57,1.82), (0.026,0.012,0.018), MAT_SKIN, 1)
sphere('right_thin_nose_wing', (0.04,-0.57,1.82), (0.026,0.012,0.018), MAT_SKIN, 1)
sphere('thin_sunken_upper_lip', (0,-0.535,1.66), (0.145,0.014,0.025), MAT_LIP, 2)
sphere('thin_sunken_lower_lip', (0,-0.535,1.61), (0.135,0.016,0.022), MAT_LIP, 2)
# hair mass and strands
sphere('black_hair_mass_behind_head', (0,-0.05,1.88), (0.48,0.21,0.70), MAT_HAIR, 2)
for i,x in enumerate(np.linspace(-0.45,0.45,20)):
    z0=2.45-random.random()*0.15
    z1=0.55-random.random()*0.3
    y0=-0.45+random.uniform(-0.02,0.04)
    y1=-0.25+random.uniform(-0.05,0.10)
    cyl_between(f'loose_black_hair_strand_{i:02d}', (x,y0,z0), (x+random.uniform(-.15,.15),y1,z1), 0.006, MAT_HAIR, 6)

# ---------------- Fabric panels ----------------

def cloth_mesh(name, u_count, v_count, point_func, material):
    verts=[]; faces=[]
    for j in range(v_count):
        v=j/(v_count-1)
        for i in range(u_count):
            u=i/(u_count-1)
            verts.append(point_func(u,v))
    for j in range(v_count-1):
        for i in range(u_count-1):
            a=j*u_count+i; b=a+1; c=(j+1)*u_count+i+1; d=(j+1)*u_count+i
            faces.append([a,b,c]); faces.append([a,c,d])
    mesh=trimesh.Trimesh(vertices=np.array(verts), faces=np.array(faces), process=False)
    mesh.metadata['cloth_object'] = True
    return add(mesh, name, material)

# main red robe, wide flowing cloth covering seated body
def robe_point(u,v):
    x=(u-0.5)*(0.9+2.4*v)
    z=1.45-2.10*v + 0.08*math.sin(4*math.pi*u)*math.sin(math.pi*v)
    y=-0.58+0.50*v + 0.07*math.sin(5*math.pi*u+2*v)
    return [x,y,z]
cloth_mesh('cloth_red_outer_robe_large_simulatable_mesh', 28, 24, robe_point, MAT_RED_FABRIC)
# black back veil: big hood-like surface behind/red over shoulders
def black_veil_point(u,v):
    x=(u-0.5)*(0.78+3.20*v)
    z=2.55-2.55*v
    y=-0.16+0.30*v + 0.08*math.cos((u-0.5)*math.pi)
    return [x,y,z]
cloth_mesh('cloth_black_transparent_back_veil_simulatable_mesh', 34, 26, black_veil_point, MAT_BLACK_VEIL)
# red veil under black, slightly inside
def red_veil_point(u,v):
    x=(u-0.5)*(0.68+2.75*v)
    z=2.50-2.30*v
    y=-0.20+0.26*v + 0.04*math.cos((u-0.5)*math.pi)
    return [x,y,z]
cloth_mesh('cloth_deep_red_under_veil_simulatable_mesh', 30, 24, red_veil_point, MAT_RED_VEIL)
# gold embroidery strips along veil edges
cyl_between('left_gold_edge_on_red_veil', (-0.34,-0.18,2.45), (-1.55,0.18,-0.05), 0.018, MAT_GOLD, 8)
cyl_between('right_gold_edge_on_red_veil', (0.34,-0.18,2.45), (1.55,0.18,-0.05), 0.018, MAT_GOLD, 8)
cyl_between('left_black_veil_gold_outer_edge', (-0.44,-0.14,2.53), (-1.82,0.26,-0.20), 0.012, MAT_OLD_GOLD, 8)
cyl_between('right_black_veil_gold_outer_edge', (0.44,-0.14,2.53), (1.82,0.26,-0.20), 0.012, MAT_OLD_GOLD, 8)
# small gold motifs on fabric (sparse, separate, visible)
for i in range(80):
    x=random.uniform(-1.2,1.2); z=random.uniform(-0.55,1.30); y=-0.55+0.12*random.random()
    if random.random()<0.5:
        sphere(f'robe_gold_embroidery_dot_{i:02d}', (x,y,z), (0.018,0.006,0.018), MAT_GOLD, 1)
    else:
        box(f'robe_gold_embroidery_dash_{i:02d}', (x,y,z), (0.055,0.004,0.010), MAT_GOLD, rot=(0,0,random.uniform(0,math.pi)))

# ---------------- Ornaments: distinct gold and silver ----------------
# crown / diadem
add(torus_mesh(0.36,0.025,72,10), 'gold_crown_forehead_elliptic_base', MAT_GOLD, T(loc=(0,-0.30,2.33), scale=(1.05,0.32,1.0), rot=(math.pi/2,0,0)))
add(torus_mesh(0.42,0.025,72,10), 'gold_crown_upper_elliptic_base', MAT_GOLD, T(loc=(0,-0.26,2.46), scale=(1.03,0.26,1.0), rot=(math.pi/2,0,0)))
for i,x in enumerate(np.linspace(-0.32,0.32,9)):
    z=2.34+0.11*(1-abs(x)/0.36)
    cyl_between(f'gold_crown_vertical_filgree_{i}', (x,-0.50,2.30), (x,-0.50,z+0.12), 0.010, MAT_GOLD, 8)
for i,(x,z,material,scale) in enumerate([
    (0,2.48,MAT_RUBY,0.07), (-0.18,2.40,MAT_EMERALD,0.04), (0.18,2.40,MAT_EMERALD,0.04), (-0.31,2.34,MAT_RUBY,0.035), (0.31,2.34,MAT_RUBY,0.035)]):
    sphere(f'large_crown_separate_gem_{i}', (x,-0.515,z), (scale,0.02,scale), material, 2)
# forehead chain dangles
for i,x in enumerate(np.linspace(-0.30,0.30,9)):
    cyl_between(f'gold_forehead_chain_{i}', (x,-0.52,2.30), (x,-0.525,2.12-random.uniform(0.0,0.06)), 0.005, MAT_GOLD, 6)
    sphere(f'gold_forehead_teardrop_{i}', (x,-0.535,2.09-random.uniform(0.0,0.04)), (0.025,0.012,0.035), MAT_GOLD, 1)
# earrings / side chains
for side,x in [('left',-0.48),('right',0.48)]:
    for row,z in enumerate([2.20,2.00,1.82]):
        sphere(f'{side}_ruby_earring_gem_{row}', (x,-0.40,z), (0.055,0.018,0.055), MAT_RUBY if row!=1 else MAT_EMERALD, 2)
        torus(f'{side}_gold_earring_ring_{row}', (x,-0.40,z), 0.065,0.007, MAT_GOLD, rot=(math.pi/2,0,0), n=32, m=6)
        for k in range(5):
            xx=x+(k-2)*0.035
            cyl_between(f'{side}_earring_chain_{row}_{k}', (xx,-0.42,z-0.06), (xx,-0.42,z-0.20), 0.004, MAT_GOLD, 6)
            sphere(f'{side}_earring_silver_drop_{row}_{k}', (xx,-0.43,z-0.225), (0.016,0.008,0.025), MAT_SILVER, 1)
# neck silver choker and necklaces
for idx,z in enumerate([1.47,1.39,1.29]):
    add(torus_mesh(0.29+0.05*idx,0.012,64,8), f'separate_silver_necklace_ring_{idx}', MAT_SILVER, T(loc=(0,-0.33,z), scale=(1.0,0.27,1.0), rot=(math.pi/2,0,0)))
for i,x in enumerate(np.linspace(-0.42,0.42,13)):
    # silver coins in clear row
    sphere(f'silver_coin_choker_visible_{i}', (x,-0.55,1.36-0.09*abs(x)), (0.030,0.006,0.030), MAT_SILVER, 1)
for i,x in enumerate(np.linspace(-0.36,0.36,7)):
    sphere(f'gold_bead_between_silver_{i}', (x,-0.57,1.50-0.07*abs(x)), (0.024,0.010,0.024), MAT_GOLD, 1)
sphere('large_center_ruby_pendant_silver_frame_gem', (0,-0.60,1.17), (0.080,0.030,0.100), MAT_RUBY, 2)
torus('large_center_silver_pendant_frame', (0,-0.60,1.17), 0.105,0.010, MAT_SILVER, rot=(math.pi/2,0,0), n=48, m=8)
for i,x in enumerate(np.linspace(-0.55,0.55,15)):
    z=1.18-0.22*(1-abs(x)/0.55)
    cyl_between(f'long_gold_neck_chain_segment_{i}', (x*0.80,-0.57,1.42), (x,-0.58,z), 0.004, MAT_GOLD, 6)
    if i % 2 == 0:
        sphere(f'emerald_and_ruby_chain_bead_{i}', (x,-0.59,z), (0.025,0.010,0.025), MAT_EMERALD if i%4==0 else MAT_RUBY, 1)
# hands basic
cyl_between('left_forearm_skin_resting_on_robe', (-0.35,-0.72,0.42), (0.10,-0.65,0.20), 0.055, MAT_SKIN, 16)
sphere('left_hand_simple_on_cloth', (0.13,-0.66,0.16), (0.095,0.045,0.055), MAT_SKIN, 2)
sphere('ring_ruby_on_finger', (0.13,-0.71,0.20), (0.026,0.008,0.026), MAT_RUBY, 1)
# ---------------- Props: lamp, tea, pipe in background ----------------
# oil lamp on left shelf, main light source indicated by flame
box('left_side_shelf_for_oil_lamp', (-1.38,-0.14,0.33), (0.62,0.32,0.10), MAT_OLD_GOLD)
torus('oil_lamp_gold_base_ring', (-1.38,-0.18,0.45), 0.14,0.018, MAT_OLD_GOLD, n=36, m=8)
cyl_between('oil_lamp_bronze_stem', (-1.38,-0.18,0.45), (-1.38,-0.18,0.67), 0.035, MAT_OLD_GOLD, 16)
# glass chimney cylinder approximated and flame
add(trimesh.creation.cylinder(radius=0.115, height=0.38, sections=32), 'transparent_glass_oil_lamp_chimney', MAT_GLASS, T(loc=(-1.38,-0.18,0.82)))
cone('visible_oil_lamp_flame_only_light_source', (-1.38,-0.18,0.73), 0.055, 0.22, MAT_FLAME, 24)
# background pipe moved back and small
cyl_between('tobacco_pipe_stem_moved_to_background', (-1.10,0.05,0.43), (-0.83,0.10,0.58), 0.018, MAT_PIPE, 10)
sphere('tobacco_pipe_bowl_background', (-1.14,0.03,0.41), (0.065,0.045,0.060), MAT_PIPE, 2)
# tea/karkade glass pitcher and tray at front right
add(trimesh.creation.cylinder(radius=0.17, height=0.45, sections=36), 'old_glass_pitcher_body_with_karkade_tea', MAT_GLASS, T(loc=(1.30,-0.78,-0.23)))
add(trimesh.creation.cylinder(radius=0.15, height=0.32, sections=36), 'visible_hibiscus_tea_inside_pitcher', MAT_TEA, T(loc=(1.30,-0.78,-0.30)))
torus('pitcher_handle_clear_glass', (1.52,-0.78,-0.22), 0.12,0.012, MAT_GLASS, scale=(0.55,1,1), rot=(math.pi/2,0,0), n=36, m=6)
add(trimesh.creation.cylinder(radius=0.50, height=0.025, sections=48), 'round_metal_serving_tray', MAT_SILVER, T(loc=(1.22,-0.80,-0.55)))
add(trimesh.creation.cylinder(radius=0.08, height=0.16, sections=24), 'small_clear_tea_glass', MAT_GLASS, T(loc=(0.92,-0.86,-0.43)))
add(trimesh.creation.cylinder(radius=0.07, height=0.10, sections=24), 'small_glass_hibiscus_tea', MAT_TEA, T(loc=(0.92,-0.86,-0.46)))

# ---------------- Export ----------------
glb_path = os.path.join(OUT_DIR, 'folklore_kazakh_seated_woman_cloth_blockout.glb')
scene.export(glb_path)
print(f'Exported {glb_path}')
