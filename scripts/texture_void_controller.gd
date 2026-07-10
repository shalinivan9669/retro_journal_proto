extends Node3D

const TEX_POLYSTYRENE := "res://assets/polyhaven/void_ground/polystyrene_diff_8k.jpg"
const TEX_SNOW := "res://assets/polyhaven/void_ground/snow_01_diff_8k.jpg"
const TEX_FLOUR := "res://assets/polyhaven/void_ground/flour_diff_8k.jpg"
const TEX_MACRO_FLOUR := "res://assets/polyhaven/void_ground/macro_flour_diff_8k.jpg"
const RETURN_SCENE := "res://scenes/Main.tscn"

const GROUND_SHADER := """
shader_type spatial;

uniform sampler2D tex_a : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_b : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_c : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_d : source_color, repeat_enable, filter_linear_mipmap;
uniform float uv_scale = 0.08;
uniform float micro_scale = 0.31;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 world_uv = (UV - vec2(0.5)) * (1.0 / max(uv_scale, 0.001));
	float n1 = noise(world_uv * 0.65);
	float n2 = noise(world_uv * 1.7 + vec2(18.0, 4.0));
	float n3 = noise(world_uv * 3.3 - vec2(2.0, 11.0));
	vec3 a = texture(tex_a, world_uv).rgb;
	vec3 b = texture(tex_b, world_uv * 1.13 + vec2(0.21, 0.37)).rgb;
	vec3 c = texture(tex_c, world_uv * 0.92 - vec2(0.18, 0.09)).rgb;
	vec3 d = texture(tex_d, world_uv * micro_scale + vec2(n2 * 0.08, n3 * 0.08)).rgb;
	vec3 base = mix(a, b, smoothstep(0.18, 0.72, n1));
	base = mix(base, c, smoothstep(0.36, 0.78, n2) * 0.52);
	base = mix(base, d, smoothstep(0.52, 0.86, n3) * 0.46);
	ALBEDO = base * vec3(0.92, 0.92, 0.88);
	ROUGHNESS = 1.0;
}
"""


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_build_void_ground()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(RETURN_SCENE)


func _build_void_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "FlatMixedTextureGround"
	add_child(ground)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GroundMesh"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(420.0, 420.0)
	mesh.subdivide_width = 128
	mesh.subdivide_depth = 128
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, _make_ground_material())
	ground.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(420.0, 0.18, 420.0)
	collision.shape = shape
	collision.position = Vector3(0.0, -0.09, 0.0)
	ground.add_child(collision)


func _make_ground_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tex_a", load(TEX_POLYSTYRENE))
	material.set_shader_parameter("tex_b", load(TEX_SNOW))
	material.set_shader_parameter("tex_c", load(TEX_FLOUR))
	material.set_shader_parameter("tex_d", load(TEX_MACRO_FLOUR))
	return material
