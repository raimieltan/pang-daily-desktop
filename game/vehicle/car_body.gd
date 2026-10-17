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

@export_enum("awd_gsr", "awd_gsr_drift", "fwd_worn_sedan", "fwd_worn_sedan_drift") var preset := "awd_gsr"
## Tire product on all four corners. The GSR leaves the factory on street rubber; the worn sedan on eco.
@export_enum("stock", "street") var tire_product := "street"

## A body contact this step: { point, normal, dv (m/s of impulse), slide (m/s along the surface) }.
## Read by effects after the physics step; side hits (walls, rails) only.
signal wall_contact(point: Vector3, normal: Vector3, dv: float, slide: float)

var model: HandlingModel
## Tuning steps on top of the preset (CarSetup), empty for stock.
var setup := {}
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
## Replay playback: while set, each step poses the car from `replay_frame` instead of the sim.
var replaying := false
var replay_frame := PackedFloat32Array()
var _live_layers := Vector2i.ZERO


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
	# Roadside traffic yields to every car (RoadsideLife).
	add_to_group(&"cars")
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


## Swap between a car's stock and drift tune.
func toggle_tune() -> void:
	set_preset(preset.trim_suffix("_drift") if preset.ends_with("_drift") else preset + "_drift")


func set_preset(id: String) -> void:
	preset = id
	_apply_config()
	_update_mass()


## The player's setup (CarSetup values) laid over the preset's physical config.
func set_setup(values: Dictionary) -> void:
	setup = values.duplicate(true)
	_apply_config()


func _apply_config() -> void:
	model.set_config(CarSetup.apply(HandlingPresets.physical_config(HandlingPresets.resolve(preset)), setup))


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
	if replaying:
		if replay_frame.size() >= REPLAY_STRIDE:
			_apply_replay(state)
		return
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


## Leaning on a rail: the body is frictionless in the engine so a brush never snags, and the scrub
## comes from here instead: RAIL_MU times the push into the rail (capped at RAIL_DRAG_MAX_G),
## against the slide, at the contact point, so a long lean also turns the car. Enough that riding
## a guardrail through a hairpin is slower than driving it (tests/probe_rail_scrub.gd).
const RAIL_MU := 0.35
const RAIL_DRAG_MAX_G := 2.5
const RAIL_SLIDE_MIN := 0.5
static var rail_scrub := true


static func rail_drag(impulse: float, slide: float, dt: float, mass_: float) -> float:
	if slide < RAIL_SLIDE_MIN:
		return 0.0
	return minf(RAIL_MU * impulse / dt, RAIL_DRAG_MAX_G * 9.81 * mass_)


func _report_contacts(state: PhysicsDirectBodyState3D, up: Vector3) -> void:
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		# Walls and rails only: the road and terrain under the car push mostly up.
		if absf(normal.dot(up)) > 0.8:
			continue
		var point := state.get_contact_local_position(i)
		var velocity := state.get_contact_local_velocity_at_position(i)
		var along := velocity - normal * velocity.dot(normal)
		var slide := along.length()
		var impulse := state.get_contact_impulse(i).length()
		var dv := impulse / mass
		if rail_scrub:
			var drag := rail_drag(impulse, slide, state.step, mass)
			if drag > 0.0:
				state.apply_force(-along / slide * drag, point - state.transform.origin)
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


# ---------------------------------------------------------------- replay
## Floats per recorded car frame: pose, velocities, pedals/engine, then 11 per wheel.
const REPLAY_STRIDE := 18 + 4 * 11


## Appends this step's pose and everything the visual, effects and audio read (see REPLAY_STRIDE).
func capture_replay(out: PackedFloat32Array) -> void:
	var xf := global_transform
	var q := xf.basis.get_rotation_quaternion()
	var s := model.state
	var mech := model.mechanics
	out.append_array([xf.origin.x, xf.origin.y, xf.origin.z, q.x, q.y, q.z, q.w,
		linear_velocity.x, linear_velocity.y, linear_velocity.z, angular_velocity.x, angular_velocity.y, angular_velocity.z,
		s.throttle, s.brake, 1.0 if s.reversing else 0.0, mech.engine_rpm, s.steer_angle])
	for i in 4:
		var c := solver.corners[i]
		var w := mech.wheels[i]
		out.append_array([c.steering_angle, c.wheel_position.y, 1.0 if c.is_grounded else 0.0, w.angular_velocity,
			w.slip_angle, w.slip_ratio, 1.0 if w.is_locked else 0.0, w.slip_energy, _points[i].x, _points[i].y, _points[i].z])


## Hand the car to (or back from) a replay: no collisions or gravity while it is posed.
func set_replaying(on: bool) -> void:
	if on == replaying:
		return
	replaying = on
	if on:
		_live_layers = Vector2i(collision_layer, collision_mask)
		collision_layer = 0
		collision_mask = 0
		gravity_scale = 0.0
	else:
		# Land on the last frame now: the next step must already be live.
		if replay_frame.size() >= REPLAY_STRIDE:
			var rid := get_rid()
			var f := replay_frame
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, _replay_transform(f))
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3(f[7], f[8], f[9]))
			PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3(f[10], f[11], f[12]))
			_apply_replay_state(f)
		collision_layer = _live_layers.x
		collision_mask = _live_layers.y
		gravity_scale = 1.0
		replay_frame = PackedFloat32Array()
		_hold_anchor = null


func _apply_replay(state: PhysicsDirectBodyState3D) -> void:
	var f := replay_frame
	state.transform = _replay_transform(f)
	state.linear_velocity = Vector3(f[7], f[8], f[9])
	state.angular_velocity = Vector3(f[10], f[11], f[12])
	_apply_replay_state(f)


static func _replay_transform(f: PackedFloat32Array) -> Transform3D:
	return Transform3D(Basis(Quaternion(f[3], f[4], f[5], f[6]).normalized()), Vector3(f[0], f[1], f[2]))


func _apply_replay_state(f: PackedFloat32Array) -> void:
	var s := model.state
	s.throttle = f[13]
	s.brake = f[14]
	s.reversing = f[15] > 0.5
	model.mechanics.engine_rpm = f[16]
	s.steer_angle = f[17]
	for i in 4:
		var o := 18 + i * 11
		var c := solver.corners[i]
		var w := model.mechanics.wheels[i]
		c.steering_angle = f[o]
		c.wheel_position.y = f[o + 1]
		c.is_grounded = f[o + 2] > 0.5
		w.is_grounded = c.is_grounded
		w.angular_velocity = f[o + 3]
		w.slip_angle = f[o + 4]
		w.slip_ratio = f[o + 5]
		w.is_locked = f[o + 6] > 0.5
		w.slip_energy = f[o + 7]
		_points[i] = Vector3(f[o + 8], f[o + 9], f[o + 10])
		_normals[i] = Vector3.UP
