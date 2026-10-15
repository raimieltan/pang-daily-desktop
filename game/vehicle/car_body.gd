class_name CarBody
extends RigidBody3D
## Jolt adapter for the handling sim. Port of `VehicleBody` + `SuspensionRuntime` + `VehicleController`:
## each physics step samples the chassis motion and road, solves suspension and tire forces in the
## engine-agnostic sim, then lets Jolt integrate the chassis from those forces.
##
## Frames: the sim works in car space with +z forward and +x right. The body faces -Z (Godot
## convention), so car-space (x, y, z) is body-local (x, y, -z). Sim yaw is positive turning right,
## which is negative angular velocity about up in Godot's right-handed frame.

const G := 9.81
## Per-second pull back to the spot the car was held at. Soaks up solver drift on slopes.
const HOLD_ANCHOR_RATE := 10.0
const SPAWN_PROBE_HEIGHT := 5.0
const SPAWN_PROBE_DEPTH := 50.0
const SPAWN_CLEARANCE := 0.03
const STATIC_LAYER := 1
const VEHICLE_LAYER := 2

## Physics representation, independent of the visual mesh (TS `VehicleCollisionConfig`). Dalagan values.
var collision_config := {
	"body": { "width": 1.66, "height": 1.1, "length": 4.3, "bottomY": 0.25, "centerZ": 0.0 },
	"wheels": { "halfTrack": 0.728, "frontZ": 1.28, "rearZ": -1.22, "radius": 0.3 },
	"centerOfMass": { "y": 0.35, "z": 0.33 },
	"angularDamping": 0.5,
}

@export_enum("fwd_worn_sedan", "fwd_worn_sedan_drift") var preset := "fwd_worn_sedan"
## Tire product on all four corners. The Babylon starter car leaves the factory on stock eco rubber.
@export_enum("stock", "street") var tire_product := "stock"

## A body contact this step: { point, normal, dv (m/s of impulse), slide (m/s along the surface) }.
## Read by effects after the physics step; side hits (walls, rails) only.
signal wall_contact(point: Vector3, normal: Vector3, dv: float, slide: float)

var model: HandlingModel
var solver: SuspensionSolver
var contact := VehicleTypes.AxleContact.new()
## Returns a `VehicleTypes.DriverInput` for this step. Defaults to no input.
var input_source: Callable = func() -> VehicleTypes.DriverInput: return VehicleTypes.DriverInput.new()
var last_input := VehicleTypes.DriverInput.new()

var _sus_input := SuspensionSolver.StepInput.new()
var _points: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _normals: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
var _previous_velocities: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
var _hold_anchor = null
## Set by a teleport: the car stays parked, even through its landing, until driven.
var _parked := true
var _pending_place = null
var _z_offset := 0.0
var _cg_height := 0.52


func _ready() -> void:
	model = HandlingModel.new(HandlingPresets.resolve(preset))
	var baseline := HandlingPresets.suspension_baseline(model.config)
	baseline["radius"] = collision_config["wheels"]["radius"]
	solver = SuspensionSolver.new(baseline, SuspensionData.create_suspension(baseline))
	_cg_height = baseline["cgHeight"]
	_z_offset = collision_config["wheels"]["frontZ"] - baseline["wheelbase"] * (1.0 - baseline["frontWeight"])
	contact.wheels = [false, false, false, false]
	set_tire_product(tire_product)

	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = VEHICLE_LAYER
	collision_mask = STATIC_LAYER | VEHICLE_LAYER
	can_sleep = false
	continuous_cd = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = collision_config["angularDamping"]
	var material := PhysicsMaterial.new()
	material.friction = 0.0
	material.bounce = 0.0
	physics_material_override = material

	# Body box only: the suspension rays carry the car, as in the TS suspension mode.
	var box: Dictionary = collision_config["body"]
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(box["width"], box["height"], box["length"])
	shape.shape = box_shape
	shape.position = Vector3(0.0, box["bottomY"] + box["height"] / 2.0, -box["centerZ"])
	add_child(shape)
	_update_mass()


## Solid-box inertia for the collision box (absolute kg·m², unlike Havok's per-unit-mass).
func _update_mass() -> void:
	var m: float = model.config["chassis"]["massKg"]
	var box: Dictionary = collision_config["body"]
	var w2: float = box["width"] * box["width"]
	var h2: float = box["height"] * box["height"]
	var l2: float = box["length"] * box["length"]
	mass = m
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, _cg_height, -collision_config["centerOfMass"]["z"])
	inertia = Vector3(m * (h2 + l2) / 12.0, m * (w2 + l2) / 12.0, m * (w2 + h2) / 12.0)
	solver.baseline["mass"] = m


func set_preset(id: String) -> void:
	preset = id
	model.set_config(HandlingPresets.resolve(id))
	_update_mass()


## Fresh, warm tires of a product on dry asphalt (TS `tireResponse` for a new assembly).
func set_tire_product(product: String) -> void:
	tire_product = product
	for t in model.tires:
		if product == "stock":
			t.grip = 0.80
			t.longitudinal_grip = 0.82
			t.slip_scale = 1.314
		else:
			t.grip = 1.0
			t.longitudinal_grip = 1.0
			t.slip_scale = 1.0


## Teleport onto the road under `position`, level with the ground normal, at rest.
func place(position_: Vector3, heading_rad: float) -> void:
	_pending_place = { "position": position_, "heading": heading_rad }


func speed_kmh() -> float:
	return -linear_velocity.dot(global_basis.z) * 3.6


## Car-space point (x right, y up, z forward) → world, with the step's transform.
func _to_world(xf: Transform3D, x: float, y: float, z: float) -> Vector3:
	return xf * Vector3(x, y, -z)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	if _pending_place != null:
		_apply_place(state)
		return
	var xf := state.transform
	var forward := -xf.basis.z
	var right := xf.basis.x
	var up := xf.basis.y
	var linear := state.linear_velocity
	var angular := state.angular_velocity
	var v_up := linear.dot(up)
	model.sync_motion(linear.dot(forward), linear.dot(right), -angular.dot(up))
	_step_suspension(state, xf, dt, linear, angular, up, right)
	var input: VehicleTypes.DriverInput = input_source.call()
	last_input = input
	model.step(dt, input, contact)
	# Any drive demand releases the parking hold; in reverse the brake pedal is the drive pedal.
	if input.throttle > 0.01 or model.state.reversing:
		_parked = false
	var grounded := contact.front + contact.rear > 0.0

	# The sim predicts planar motion to solve wheel slip, but Jolt integrates the actual chassis
	# once from these forces. Never overwrite its yaw/pitch/roll velocities.
	if grounded and (model.diagnostics.held or _parked):
		# Static brake constraint, as impulses: cancel planar and yaw motion and pull back to the
		# held spot. Vertical suspension settling stays free.
		var com_offset := state.center_of_mass
		if _hold_anchor == null:
			_hold_anchor = xf.origin
		var target: Vector3 = (_hold_anchor - xf.origin) * HOLD_ANCHOR_RATE
		target -= up * target.dot(up)
		var planar := linear - up * v_up
		state.apply_impulse((target - planar) * mass, com_offset)
		var gravity := state.total_gravity
		var along_gravity := gravity - up * gravity.dot(up)
		state.apply_force(-along_gravity * mass, com_offset)
		state.apply_torque_impulse(up * (-angular.dot(up) * inertia.y))
	else:
		_hold_anchor = null
	_apply_tire_forces(state, xf, forward, up)
	_report_contacts(state, up)


func _report_contacts(state: PhysicsDirectBodyState3D, up: Vector3) -> void:
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		# Walls and rails only: the road and terrain under the car push mostly up.
		if absf(normal.dot(up)) > 0.8:
			continue
		var point := state.get_contact_local_position(i)
		var velocity := state.get_contact_local_velocity_at_position(i)
		var slide := (velocity - normal * velocity.dot(normal)).length()
		var dv := state.get_contact_impulse(i).length() / mass
		wall_contact.emit.call_deferred(point, normal, dv, slide)


## World contact point and ground normal under wheel `i` (FL, FR, RL, RR) from the last step.
func wheel_contact(i: int) -> Dictionary:
	return { "point": _points[i], "normal": _normals[i], "grounded": solver.corners[i].is_grounded }


func _step_suspension(state: PhysicsDirectBodyState3D, xf: Transform3D, dt: float, linear: Vector3, angular: Vector3,
		up: Vector3, right: Vector3) -> void:
	var space := state.get_space_state()
	var setup: Dictionary = solver.saved["setup"]
	var b := solver.baseline
	var wheels: Dictionary = collision_config["wheels"]
	var cg := _to_world(xf, 0.0, _cg_height, collision_config["centerOfMass"]["z"])
	for i in 4:
		var c := solver.corners[i]
		var setting: Dictionary = setup["corners"][i]
		var x := c.wheel_position.x
		if x == 0.0:
			x = wheels["halfTrack"] * (1.0 if i % 2 == 1 else -1.0)
		var z := c.wheel_position.z
		if z == 0.0:
			z = b["wheelbase"] * (1.0 - b["frontWeight"]) if i < 2 else -b["wheelbase"] * b["frontWeight"]
		z += _z_offset
		var mount := _to_world(xf, x, 0.0, z)
		_sus_input.mounts[i] = mount.dot(up)
		var lever := mount - cg
		_sus_input.velocities[i] = (linear + angular.cross(lever)).dot(up)
		var from: Vector3 = mount + up * (solver.radii[i] + setting["compressionTravel"] + 0.1)
		var to: Vector3 = mount - up * (setting["droopTravel"] + maxf(0.0, setting["rideHeight"]) + 0.2)
		var query := PhysicsRayQueryParameters3D.create(from, to, STATIC_LAYER, [get_rid()])
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and (hit["normal"] as Vector3).dot(up) > 0.2:
			_sus_input.roads[i] = (hit["position"] as Vector3).dot(up)
			_points[i] = hit["position"]
			_normals[i] = hit["normal"]
		else:
			_sus_input.roads[i] = NAN
			_points[i] = mount
			_normals[i] = up
		_sus_input.disabled[i] = not model.tires[i].installed or model.tires[i].raised
	_sus_input.steering = model.state.steer_angle
	_sus_input.damage = true
	for i in 4:
		_sus_input.accelerations[i] = clampf((_sus_input.velocities[i] - _previous_velocities[i]) / dt, -100.0, 100.0)
	solver.step(dt, _sus_input)
	for i in 4:
		_previous_velocities[i] = _sus_input.velocities[i]
	# Actual contact replaces the long ray's candidate contact.
	for i in 4:
		var c := solver.corners[i]
		var n := _normals[i]
		c.road_camber = c.camber - (1.0 if i % 2 == 1 else -1.0) * atan2(n.dot(right), n.dot(up))
		c.has_road_camber = true
		contact.wheels[i] = c.is_grounded
	contact.front = (float(solver.corners[0].is_grounded) + float(solver.corners[1].is_grounded)) / 2.0
	contact.rear = (float(solver.corners[2].is_grounded) + float(solver.corners[3].is_grounded)) / 2.0
	contact.suspension = solver.corners


func _apply_tire_forces(state: PhysicsDirectBodyState3D, xf: Transform3D, forward: Vector3, up: Vector3) -> void:
	var origin := xf.origin
	var setup: Dictionary = solver.saved["setup"]
	for i in 4:
		var c := solver.corners[i]
		var mount := _to_world(xf, c.wheel_position.x, _cg_height, c.wheel_position.z + _z_offset)
		var unsprung_weight: float = setup["corners"][i]["unsprungMass"] * G if c.is_grounded else 0.0
		state.apply_force(up * c.suspension_force + Vector3.UP * unsprung_weight, mount - origin)
	for i in 4:
		if not solver.corners[i].is_grounded:
			continue
		var f := model.mechanics.applied_forces[i]
		var n := _normals[i]
		var fwd := (forward - n * forward.dot(n)).normalized()
		var rgt := fwd.cross(n).normalized()
		state.apply_force(fwd * f.x + rgt * f.y, _points[i] - origin)
	var linear := state.linear_velocity
	var aero: float = model.config["drive"]["aeroDrag"]
	var cg := _to_world(xf, 0.0, _cg_height, collision_config["centerOfMass"]["z"])
	state.apply_force(linear * (-aero * mass * linear.length()), cg - origin)


func _apply_place(state: PhysicsDirectBodyState3D) -> void:
	var p: Vector3 = _pending_place["position"]
	var heading: float = _pending_place["heading"]
	_pending_place = null
	var space := state.get_space_state()
	var from := p + Vector3.UP * SPAWN_PROBE_HEIGHT
	var to := from + Vector3.DOWN * (SPAWN_PROBE_HEIGHT + SPAWN_PROBE_DEPTH)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, STATIC_LAYER, [get_rid()]))
	if hit.is_empty():
		return
	var normal: Vector3 = (hit["normal"] as Vector3).normalized()
	var heading_q := Quaternion(Vector3.UP, heading)
	var tilt := Quaternion(Vector3.UP, normal) if Vector3.UP.cross(normal).length() > 1e-6 else Quaternion.IDENTITY
	state.transform = Transform3D(Basis(tilt * heading_q), (hit["position"] as Vector3) + normal * SPAWN_CLEARANCE)
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	model.reset()
	solver.reset()
	_previous_velocities = [0.0, 0.0, 0.0, 0.0]
	_hold_anchor = null
	_parked = true

