class_name BalkhashRoadEnvironment
extends Node3D

@export_range(40.0, 500.0, 1.0) var fog_distance := 210.0
@export_range(0.0, 1.0, 0.01) var ambient_energy := 0.045
@export_range(0.0, 1.0, 0.01) var backdrop_opacity := 0.68

const PACK_ROOT := "res://LostSignal_RoadScene_CodexPack/"


func _ready() -> void:
	_build_world_environment()
	_build_backdrop_layers()


func _build_world_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "BalkhashNightWorld"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = load(PACK_ROOT + "sky/qwantani_night_puresky_4k.hdr") as Texture2D
	panorama.energy_multiplier = 0.22
	sky.sky_material = panorama
	environment.sky = sky
	environment.background_energy_multiplier = 0.045
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = ambient_energy
	environment.ambient_light_sky_contribution = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 2.1
	environment.ssao_power = 1.35
	environment.ssil_enabled = true
	environment.ssil_radius = 2.4
	environment.ssil_intensity = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.075, 0.105, 0.135)
	environment.fog_light_energy = 0.24
	environment.fog_density = 1.0 / maxf(fog_distance, 1.0)
	environment.fog_sky_affect = 0.18
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0032
	environment.volumetric_fog_albedo = Color(0.34, 0.38, 0.42)
	environment.volumetric_fog_emission_energy = 0.0
	environment.volumetric_fog_length = 140.0
	environment.volumetric_fog_detail_spread = 1.8
	environment.volumetric_fog_ambient_inject = 0.035
	environment.volumetric_fog_temporal_reprojection_enabled = true
	world.environment = environment
	add_child(world)


func _build_backdrop_layers() -> void:
	var layers: Array[Dictionary] = [
		{"name": "LakeBalkhashLeft", "file": "01_lake_balkhash_band_8k.png", "size": Vector2(265.0, 13.0), "pos": Vector3(-82.0, 4.4, -205.0), "alpha": 0.68},
		{"name": "SaltShore", "file": "02_salt_shore_band_8k.png", "size": Vector2(310.0, 14.0), "pos": Vector3(-45.0, 4.0, -198.0), "alpha": 0.72},
		{"name": "MountainsFar", "file": "03_mountains_far_8k.png", "size": Vector2(350.0, 43.0), "pos": Vector3(0.0, 16.0, -220.0), "alpha": 0.88},
		{"name": "BektauAta", "file": "04_mountains_mid_bektau_8k.png", "size": Vector2(320.0, 38.0), "pos": Vector3(32.0, 13.0, -204.0), "alpha": 0.88},
		{"name": "Foothills", "file": "05_foothills_near_8k.png", "size": Vector2(305.0, 27.0), "pos": Vector3(8.0, 8.0, -188.0), "alpha": 0.78},
		{"name": "HorizonHaze", "file": "06_horizon_haze_band_8k.png", "size": Vector2(340.0, 25.0), "pos": Vector3(0.0, 10.0, -180.0), "alpha": 0.42},
	]
	for layer_data in layers:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = String(layer_data.name)
		var quad := QuadMesh.new()
		quad.size = layer_data.size
		quad.orientation = PlaneMesh.FACE_Z
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.albedo_texture = load(PACK_ROOT + "backdrops/runtime_8k/" + String(layer_data.file)) as Texture2D
		material.albedo_color = Color(0.34, 0.39, 0.46, float(layer_data.alpha) * backdrop_opacity)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = material
		mesh_instance.mesh = quad
		mesh_instance.position = layer_data.pos
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
