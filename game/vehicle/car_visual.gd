class_name CarVisual
extends Node3D
## The car's GLB, driven from the sim: wheels steer, spin and follow suspension travel.
## The GLB faces +Z (glTF), the body faces -Z, so the model sits under a 180° yaw.

const WHEEL_NAMES := ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]

@export var model_scene: PackedScene = preload("res://assets/vehicles/dalagan_evo/dalagan_evo_modular.glb")
## The car is the color on the page (docs/ART_DIRECTION.md §3).
const PLAYER_PAINT := Color(0.96, 0.74, 0.08)
@export var paint_color := PLAYER_PAINT

const STREAK_SHADER := preload("res://game/art/manga_streak.gdshader")
const CAR_RENDER_LAYER := 2

var car: CarBody
var _materials := {}
var _tail_streaks: Array[MeshInstance3D] = []
var _streak := 0.0
var _headlights: Array[SpotLight3D] = []
var _hubs: Array[Node3D] = []
var _wheels: Array[Node3D] = []
var _rest_y: PackedFloat64Array = []
var _spin: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	rotation.y = PI
	var model := model_scene.instantiate()
	add_child(model)
	_materials = MangaArt.apply_car(model, paint_color)
	# The car's own lamps light the world, not the car (render layer 2 is skipped by its lights).
	for m in model.find_children("*", "VisualInstance3D", true, false):
		(m as VisualInstance3D).layers = CAR_RENDER_LAYER
	_build_lamps.call_deferred(model)
	for name in WHEEL_NAMES:
		var wheel := model.find_child(name, true, false) as Node3D
		if wheel == null:
			push_warning("CarVisual: %s not found in the GLB" % name)
			_hubs.append(null); _wheels.append(null); _rest_y.append(0.0)
			continue
		# Pivot each wheel on a hub at its geometric centre, whatever the mesh origin.
		var center := _mesh_center(wheel)
		var hub := Node3D.new()
		hub.name = name + "_hub"
		add_child(hub)
		hub.global_position = center
		var keep := wheel.global_transform
		wheel.get_parent().remove_child(wheel)
		hub.add_child(wheel)
		wheel.global_transform = keep
		_hubs.append(hub)
		_wheels.append(wheel)
		_rest_y.append(hub.position.y)


## Lamps from the GLB's light meshes: a red reflection streak on the road behind each taillight
## while braking (faint at night), warm headlight spots at night. Selective color on the page.
func _build_lamps(model: Node) -> void:
	for name in ["taillight_l", "taillight_r"]:
		var node := model.find_child(name, true, false) as Node3D
		if node == null:
			continue
		var trail := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var m := ShaderMaterial.new()
		m.shader = STREAK_SHADER
		quad.material = m
		trail.mesh = quad
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The trail is placed in the vertex shader; keep culling from dropping it.
		trail.extra_cull_margin = 4.0
		add_child(trail)
		# At the lamp's face, +Z pointing behind the car (the GLB faces +Z, so behind is −Z).
		trail.position = to_local(_mesh_center(node)) + Vector3(0, 0, -0.04)
		trail.rotation.y = PI
		_tail_streaks.append(trail)
	for name in ["headlight_l", "headlight_r"]:
		var node := model.find_child(name, true, false) as Node3D
		if node == null:
			continue
		var spot := SpotLight3D.new()
		spot.light_color = Color.WHITE
		spot.spot_range = 48.0
		spot.spot_angle = 26.0
		spot.spot_attenuation = 0.5
		# Near-flat across the cone, then a hard drop at its edge: a cut-out white beam.
		spot.spot_angle_attenuation = 0.05
		spot.light_energy = 0.0
		spot.shadow_enabled = false
		spot.light_cull_mask = 1
		spot.visible = false
		add_child(spot)
		spot.global_position = _mesh_center(node)
		# GLB faces +Z; tilt the beam down onto the road.
		spot.rotation = Vector3(-0.17, PI, 0.0)
		_headlights.append(spot)


func _update_lamps(delta: float) -> void:
	var s := car.model.state
	var braking := s.brake if not s.reversing else 0.0
	var night := MangaArt.night
	var tail := clampf(braking * 1.4 + night * 0.35, 0.0, 1.6)
	var tail_mat: ShaderMaterial = _materials.get("taillight")
	if tail_mat:
		tail_mat.set_shader_parameter("glow", tail)
	var head_mat: ShaderMaterial = _materials.get("headlight")
	if head_mat:
		head_mat.set_shader_parameter("glow", night * 1.2)
	var reverse_mat: ShaderMaterial = _materials.get("reverse")
	if reverse_mat:
		reverse_mat.set_shader_parameter("glow", 1.0 if s.reversing else 0.0)
	# Brake light trails: brighter at night (tail lamps are on), longer with speed.
	_streak = move_toward(_streak, braking * lerpf(0.35, 1.2, night) + night * 0.3, delta * 8.0)
	var length := 0.3 + clampf(car.linear_velocity.length() * 0.07, 0.0, 2.2)
	for st in _tail_streaks:
		st.visible = _streak > 0.02
		var m := (st.mesh as QuadMesh).material as ShaderMaterial
		m.set_shader_parameter("intensity", _streak)
		m.set_shader_parameter("trail_length", length)
	for spot in _headlights:
		spot.visible = night > 0.02
		spot.light_energy = 3.5 * night


func _process(delta: float) -> void:
	if car == null or car.model == null:
		return
	_update_lamps(delta)
	var radius: float = car.collision_config["wheels"]["radius"]
	for i in 4:
		var hub := _hubs[i]
		if hub == null:
			continue
		var corner := car.solver.corners[i]
		var wheel_state := car.model.mechanics.wheels[i]
		# Sim steer is right-positive; +Y yaw turns the +Z-facing GLB to its left.
		hub.rotation.y = -corner.steering_angle
		hub.position.y = _rest_y[i] + (corner.wheel_position.y - radius)
		_spin[i] = fmod(_spin[i] + wheel_state.angular_velocity * delta, TAU)
		_wheels[i].rotation.x = _spin[i]


static func _mesh_center(node: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	var meshes: Array[Node] = []
	if node is MeshInstance3D:
		meshes.append(node)
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for m in meshes:
		var mesh_instance := m as MeshInstance3D
		var world := mesh_instance.global_transform * mesh_instance.get_aabb()
		box = world if first else box.merge(world)
		first = false
	return box.get_center() if not first else node.global_position
