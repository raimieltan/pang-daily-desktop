extends Node3D
## Drive test: one car on an open lot with ramps, bumps and a cone slalom, for judging driving feel.
## Built in code so the layout is easy to tweak and diff.

const SPAWN := Vector3(0.0, 0.5, 20.0)
const SPAWN_HEADING := 0.0
const CONE_LAYER := 4

var car: CarBody
var camera: ChaseCamera
var hud: TelemetryHud
var _input := PlayerInput.new()


func _ready() -> void:
	PlayerInput.register_actions()
	_build_environment()
	_build_ground()
	_build_features()

	car = CarBody.new()
	car.name = "Dalagan"
	car.collision_mask |= CONE_LAYER
	car.input_source = _input.read
	add_child(car)
	car.global_position = SPAWN
	var visual := CarVisual.new()
	visual.car = car
	car.add_child(visual)
	car.place(SPAWN, SPAWN_HEADING)

	camera = ChaseCamera.new()
	camera.target = car
	add_child(camera)
	camera.global_position = SPAWN + Vector3(0, 2, 6)
	camera.current = true

	hud = TelemetryHud.new()
	hud.car = car
	add_child(hud)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_car"):
		car.place(SPAWN, SPAWN_HEADING)
		camera.snap.call_deferred()
	elif event.is_action_pressed("toggle_tune"):
		car.set_preset("fwd_worn_sedan_drift" if car.preset == "fwd_worn_sedan" else "fwd_worn_sedan")
	elif event.is_action_pressed("toggle_tires"):
		car.set_tire_product("street" if car.tire_product == "stock" else "stock")
	elif event.is_action_pressed("toggle_hud"):
		hud.visible = not hud.visible


func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.5, 0.78)
	sky_material.sky_horizon_color = Color(0.78, 0.82, 0.86)
	sky_material.ground_horizon_color = Color(0.6, 0.6, 0.58)
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


func _static_box(size: Vector3, xf: Transform3D, color: Color, material: Material = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CarBody.STATIC_LAYER
	body.collision_mask = 0
	body.transform = xf
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	if material == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		material = m
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)
	return body


func _build_ground() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_pos.xz;
	vec2 g1 = abs(fract(p / 2.0 - 0.5) - 0.5) / fwidth(p / 2.0);
	vec2 g10 = abs(fract(p / 10.0 - 0.5) - 0.5) / fwidth(p / 10.0);
	float minor = 1.0 - min(min(g1.x, g1.y), 1.0);
	float major = 1.0 - min(min(g10.x, g10.y), 1.0);
	vec3 asphalt = vec3(0.16, 0.165, 0.17);
	ALBEDO = mix(asphalt, vec3(0.32), max(minor * 0.35, major * 0.8));
	ROUGHNESS = 0.92;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_static_box(Vector3(600, 1, 600), Transform3D(Basis(), Vector3(0, -0.5, 0)), Color.WHITE, material)


func _build_features() -> void:
	var concrete := Color(0.55, 0.55, 0.53)
	# Ramps of increasing steepness, ahead of the spawn.
	for i in 3:
		var angle := deg_to_rad(6.0 + i * 4.0)
		var length := 8.0
		var basis := Basis(Vector3.RIGHT, angle)
		var pos := Vector3(-14.0 + i * 14.0, sin(angle) * length / 2.0 - 0.25, -40.0)
		_static_box(Vector3(5, 0.5, length), Transform3D(basis, pos), concrete)
	# Speed bumps across a straight to the right.
	for i in 6:
		var bump := Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(40.0, -0.12, 10.0 - i * 12.0))
		var body := StaticBody3D.new()
		body.collision_layer = CarBody.STATIC_LAYER
		body.transform = bump
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.25
		cyl.height = 6.0
		shape.shape = cyl
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var cyl_mesh := CylinderMesh.new()
		cyl_mesh.top_radius = 0.25
		cyl_mesh.bottom_radius = 0.25
		cyl_mesh.height = 6.0
		mesh.mesh = cyl_mesh
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.7, 0.1)
		mesh.material_override = m
		body.add_child(mesh)
		add_child(body)
	# Cone slalom on the left: 12 m spacing.
	for i in 10:
		_cone(Vector3(-40.0, 0.0, 20.0 - i * 12.0))
	# A wide skidpad ring of cones (30 m radius).
	for i in 36:
		var a := TAU * i / 36.0
		_cone(Vector3(cos(a) * 30.0, 0.0, -130.0 + sin(a) * 30.0))


func _cone(pos: Vector3) -> void:
	var cone := RigidBody3D.new()
	cone.mass = 4.0
	cone.collision_layer = CONE_LAYER
	cone.collision_mask = CarBody.STATIC_LAYER | CarBody.VEHICLE_LAYER | CONE_LAYER
	cone.position = pos + Vector3.UP * 0.36
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.16
	cyl.height = 0.7
	shape.shape = cyl
	cone.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.18
	cm.height = 0.7
	mesh.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.42, 0.05)
	mesh.material_override = m
	cone.add_child(mesh)
	add_child(cone)
