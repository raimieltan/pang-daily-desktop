class_name CarVisual
extends Node3D
## The car's GLB, driven from the sim: wheels steer, spin and follow suspension travel.
## The GLB faces +Z (glTF), the body faces -Z, so the model sits under a 180° yaw.

const WHEEL_NAMES := ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]

@export var model_scene: PackedScene = preload("res://assets/vehicles/banwa_dalagan_1996_modular.glb")

var car: CarBody
var _hubs: Array[Node3D] = []
var _wheels: Array[Node3D] = []
var _rest_y: PackedFloat64Array = []
var _spin: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	rotation.y = PI
	var model := model_scene.instantiate()
	add_child(model)
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


func _process(delta: float) -> void:
	if car == null or car.model == null:
		return
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
