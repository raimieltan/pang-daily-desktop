class_name SuspensionSolver
extends RefCounted
## Independent unsprung vertical masses coupled through a rigid chassis and axle anti-roll bars.
## Chassis integration is external (the physics body); `preview()` supplies a small rigid chassis
## for the garage and tests. Port of `src/game-core/suspension/solver.ts`.

const G := 9.81


class CornerState:
	var corner := ""
	var radius := 0.3
	## Set by the runtime from the ground normal; `camber` otherwise.
	var road_camber := 0.0
	var has_road_camber := false
	var compression := 0.0
	var compression_velocity := 0.0
	var travel_used := 0.0
	var travel_remaining_compression := 0.09
	var travel_remaining_droop := 0.06
	var spring_force := 0.0
	var damper_force := 0.0
	var bump_stop_force := 0.0
	var arb_force := 0.0
	var suspension_force := 0.0
	var wheel_load := 0.0
	var ride_height := 0.0
	var camber := 0.0
	var toe := 0.0
	var caster := 0.0
	var steering_angle := 0.0
	var heading := 0.0
	## Car frame: x right, y up, z forward (from the CG plane).
	var wheel_position := Vector3.ZERO
	var wheel_velocity := Vector3.ZERO
	var unsprung_velocity := Vector3.ZERO
	var is_grounded := false
	var rubbing := false
	var status := "NORMAL"


## Per-step inputs. `mounts`: world height of the body origin at each wheel along the suspension
## axis; `roads`: road height or NAN for no contact.
class StepInput:
	var mounts: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
	var velocities: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
	var roads: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
	var accelerations: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
	var disabled: Array[bool] = [false, false, false, false]
	var steering := 0.0
	var damage := false


## Per-corner setup/damage/alignment flattened into typed fields once per step: the integrator
## runs 10× per physics step × 4 corners, and Dictionary lookups dominated its cost.
class CornerParams:
	var front := true
	var side := -1.0
	var unsprung := 35.0
	var static_total := 0.0
	var sprung_weight := 0.0
	var stock_rate := 1.0
	var spring_rate := 1.0
	var preload_m := 0.0
	var bump := 0.0
	var rebound := 0.0
	var hs_bump := 0.0
	var hs_rebound := 0.0
	var bump_stop := 0.02
	var ride := 0.0
	var up_limit := 0.09
	var down_limit := 0.06
	var height := 0.0
	var arb := 0.0
	var h_spring := 1.0
	var h_damper := 1.0
	var h_knuckle := 1.0
	var min_health := 1.0
	var def_camber := 0.0
	var def_toe := 0.0
	var def_caster := 0.0
	var def_steer := 0.0
	var def_pos := Vector3.ZERO
	var al_camber := 0.0
	var al_toe := 0.0
	var al_caster := 0.0
	var camber := 0.0
	var toe := 0.0
	var caster := 0.0
	var track_offset := 0.0


var baseline: Dictionary
var saved: Dictionary
var corners: Array[CornerState] = []
var pose := { "heave": 0.0, "pitch": 0.0, "roll": 0.0, "velocity": 0.0, "pitchVelocity": 0.0, "rollVelocity": 0.0 }
var steering := { "steeringInput": 0.0, "rackPosition": 0.0, "leftWheelAngle": 0.0, "rightWheelAngle": 0.0, "maxLock": 0.0, "steeringRatio": 16.0, "ackermannFactor": 0.75 }
## { corner, type, intensity } impacts from the last step.
var events: Array[Dictionary] = []
var radii: PackedFloat64Array
var offsets: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
var widths: PackedFloat64Array = [0.195, 0.195, 0.195, 0.195]
var _cooldown: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
var _part: Dictionary
var _geometry: Dictionary
var _params: Array[CornerParams] = []
var _params_dirty := true
var _max_lock := 0.0
var _ackermann := 0.75


func _init(baseline_: Dictionary, saved_: Dictionary) -> void:
	baseline = baseline_
	saved = saved_
	var r: float = baseline.get("radius", 0.3)
	radii = [r, r, r, r]
	for id in VehicleTypes.CORNERS:
		var c := CornerState.new()
		c.corner = id
		c.radius = r
		c.wheel_position = Vector3(0.0, r, 0.0)
		corners.append(c)


func reset() -> void:
	pose = { "heave": 0.0, "pitch": 0.0, "roll": 0.0, "velocity": 0.0, "pitchVelocity": 0.0, "rollVelocity": 0.0 }
	for c in corners:
		c.compression = 0.0
		c.compression_velocity = 0.0
		c.wheel_load = 0.0
	_cooldown = [0.0, 0.0, 0.0, 0.0]


func step(dt: float, input: StepInput) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	events.clear()
	var span := minf(dt, 0.1)
	var steps := ceili(span * 1200.0)
	var h := span / steps
	_cache_params()
	for n in steps:
		_integrate(h, input)


func _cache_params() -> void:
	_part = SuspensionData.part(saved["part"])
	_geometry = SuspensionData.GEOMETRY[_part["geometry"]]
	var b := baseline
	var setup: Dictionary = saved["setup"]
	_max_lock = setup["maxLock"]
	_ackermann = setup["ackermann"]
	steering["maxLock"] = _max_lock
	steering["steeringRatio"] = setup["steeringRatio"]
	steering["ackermannFactor"] = _ackermann
	var mass: float = b["mass"]
	var front_weight: float = b["frontWeight"]
	_params.clear()
	for i in 4:
		var s: Dictionary = setup["corners"][i]
		var d: Dictionary = saved["damage"][i]
		var def: Dictionary = d["deformation"]
		var health: Dictionary = d["health"]
		var align: Dictionary = saved["alignment"][i]
		var c := CornerParams.new()
		c.front = i < 2
		c.side = 1.0 if i % 2 == 1 else -1.0
		c.unsprung = s["unsprungMass"]
		c.static_total = mass * G * (front_weight if c.front else 1.0 - front_weight) / 2.0
		c.sprung_weight = c.static_total - c.unsprung * G
		c.stock_rate = b["frontSpring"] if c.front else b["rearSpring"]
		c.spring_rate = s["springRate"]
		c.preload_m = s["preload"]
		c.bump = s["bump"]
		c.rebound = s["rebound"]
		c.hs_bump = s["highSpeedBump"]
		c.hs_rebound = s["highSpeedRebound"]
		c.bump_stop = s["bumpStop"]
		c.ride = s["rideHeight"]
		c.up_limit = maxf(0.005, s["compressionTravel"] + minf(0.0, c.ride) - def["travelReduction"])
		c.down_limit = s["droopTravel"]
		c.height = c.ride + def["rideHeight"]
		c.arb = setup["frontARB"] if c.front else setup["rearARB"]
		c.h_spring = health["spring"]
		c.h_damper = health["damper"]
		c.h_knuckle = health["knuckle"]
		c.min_health = 1.0
		for key in health:
			c.min_health = minf(c.min_health, health[key])
		c.def_camber = def["camber"]
		c.def_toe = def["toe"]
		c.def_caster = def["caster"]
		c.def_steer = def["steeringCenter"]
		c.def_pos = Vector3(def["position"]["x"], def["position"]["y"], def["position"]["z"])
		c.al_camber = align["camber"]
		c.al_toe = align["toe"]
		c.al_caster = align["caster"]
		c.camber = s["camber"]
		c.toe = s["toe"]
		c.caster = s["caster"]
		c.track_offset = s["trackOffset"]
		_params.append(c)


func _integrate(dt: float, input: StepInput) -> void:
	var b := baseline
	var part := _part
	var compression: PackedFloat64Array = [corners[0].compression, corners[1].compression, corners[2].compression, corners[3].compression]
	var max_lock := _max_lock
	var rack := SimMath.clamp_(input.steering, -max_lock, max_lock)
	steering["rackPosition"] = rack
	steering["steeringInput"] = rack / max_lock
	var front_weight: float = b["frontWeight"]
	var wheelbase: float = b["wheelbase"]
	var track: float = b["track"]
	var motion: float = part["motionRatio"]
	var spring_scale: float = part["springScale"]
	var geo_camber: Array = _geometry["camber"]
	var geo_toe: Array = _geometry["toe"]
	var geo_track: Array = _geometry["track"]
	var damaged := false
	for i in 4:
		var c := corners[i]
		var k := _params[i]
		var front := k.front
		var side := k.side
		var up_limit := k.up_limit
		var down_limit := k.down_limit
		var height := k.height
		var q := c.compression
		var v := c.compression_velocity
		# Spring seat preload is distance, not a stiffness multiplier. Failed springs retain fragments.
		c.spring_force = maxf(0.0, (k.sprung_weight / (k.stock_rate * spring_scale) + k.preload_m + q * motion) * k.spring_rate * motion) \
			* (0.12 + 0.88 * k.h_spring)
		var low := k.bump if v >= 0.0 else k.rebound
		var high := k.hs_bump if v >= 0.0 else k.hs_rebound
		c.damper_force = SimMath.sign_(v) * (low * minf(0.15, absf(v)) + high * maxf(0.0, absf(v) - 0.15)) * k.h_damper
		var bump := maxf(0.0, q - (up_limit - minf(k.bump_stop, up_limit * 0.7)))
		# Elastomer bump stops: progressive, lossy on unload, and never pull the wheel.
		var bump_damping := minf(1.0, bump / 0.01) * 9000.0 * v if bump > 0.0 else 0.0
		c.bump_stop_force = maxf(0.0, (300000.0 * bump + 60000000.0 * bump * bump) * (0.35 if v < 0.0 else 1.0) + bump_damping) \
			+ (600000.0 * (q - up_limit) + 2500.0 * maxf(v, 0.0) if q > up_limit else 0.0)
		var droop := 600000.0 * (q + down_limit) + 2200.0 * minf(v, 0.0) if q < -down_limit else 0.0
		c.arb_force = (compression[i] - compression[i ^ 1]) * k.arb
		c.suspension_force = c.spring_force + c.damper_force + c.bump_stop_force + c.arb_force + droop
		var road := NAN if input.disabled[i] else input.roads[i]
		var mount := input.mounts[i]
		var mount_v := input.velocities[i]
		# Radii are loaded radii. Add the static tire deflection to get the unloaded contact radius.
		var radius := radii[i]
		var tire_rate := 180000.0 * (0.3 / radius)
		var wheel_y := mount + radius - height + q
		var wheel_v := mount_v + v
		var penetration := 0.0 if is_nan(road) else road + radius + k.static_total / tire_rate - wheel_y
		# Past a sidewall's deflection the tire crushes onto the rim: very stiff, barely springs back.
		var rim := maxf(0.0, penetration - 0.08)
		var rim_share := minf(1.0, rim / 0.01)
		c.wheel_load = 0.0 if (is_nan(road) or penetration <= 0.0) else \
			maxf(0.0, tire_rate * penetration + 2000000.0 * rim * (0.2 if wheel_v > 0.0 else 1.0) - (450.0 + 12000.0 * rim_share) * wheel_v)
		c.is_grounded = c.wheel_load > 1.0
		var acceleration := (c.wheel_load - c.suspension_force) / k.unsprung - G - input.accelerations[i]
		c.compression_velocity += acceleration * dt
		c.compression += c.compression_velocity * dt
		# Compliant stops above carry forces. Hard limits bound pathological collision discontinuities.
		if c.compression > up_limit + 0.025:
			c.compression = up_limit + 0.025
			c.compression_velocity = minf(0.0, c.compression_velocity)
		if c.compression < -down_limit - 0.015:
			c.compression = -down_limit - 0.015
			c.compression_velocity = maxf(0.0, c.compression_velocity)
		c.travel_used = maxf(0.0, c.compression)
		c.travel_remaining_compression = maxf(0.0, up_limit - c.compression)
		c.travel_remaining_droop = maxf(0.0, down_limit + c.compression)
		c.ride_height = height - c.compression
		var travel := c.compression - k.ride
		var steer := 0.0
		if front:
			var r := INF if absf(rack) < 1e-6 else wheelbase / tan(absf(rack))
			var inside := side == SimMath.sign_(rack)
			var ack := SimMath.sign_(rack) * atan(wheelbase / maxf(0.1, r + (-1.0 if inside else 1.0) * track / 2.0))
			steer = rack + (ack - rack) * _ackermann
			steer = SimMath.clamp_(steer + k.def_steer, -max_lock, max_lock) * (0.2 + 0.8 * k.h_knuckle)
		c.steering_angle = steer
		c.caster = k.caster + k.def_caster + k.al_caster
		c.camber = k.camber + SuspensionData.curve_at(geo_camber, travel) + side * sin(steer) * sin(c.caster) + k.def_camber + k.al_camber
		c.toe = k.toe + SuspensionData.curve_at(geo_toe, travel) + k.def_toe + k.al_toe
		c.heading = steer - side * c.toe
		c.radius = radius
		c.wheel_position = Vector3(side * (track / 2.0 + k.track_offset + offsets[i] + SuspensionData.curve_at(geo_track, travel)) + k.def_pos.x,
			radius - height + c.compression + k.def_pos.y,
			(wheelbase * (1.0 - front_weight) if front else -wheelbase * front_weight) - travel * 0.04 + k.def_pos.z)
		c.wheel_velocity = Vector3(0.0, c.compression_velocity, -c.compression_velocity * 0.04)
		c.unsprung_velocity = Vector3(0.0, wheel_v, 0.0)
		c.rubbing = c.compression - height > 0.055 and widths[i] / 2.0 + absf(sin(c.heading)) * radius + offsets[i] > 0.16
		var min_health := k.min_health
		if min_health < 0.15: c.status = "FAILED"
		elif min_health < 0.8: c.status = "DAMAGED"
		elif c.compression >= up_limit: c.status = "BOTTOMED"
		elif c.travel_remaining_droop < 0.002: c.status = "FULL DROOP"
		elif not c.is_grounded: c.status = "AIRBORNE"
		elif bump > 0.0: c.status = "NEAR BUMP STOP"
		else: c.status = "NORMAL"
		_cooldown[i] = maxf(0.0, _cooldown[i] - dt)
		# Riding the elastomer bump stops is normal on a lowered car; only bottoming past the
		# hard limit, or a tire spike, is an impact that can bend parts.
		var hard_stop := 600000.0 * (c.compression - up_limit) if c.compression > up_limit else 0.0
		if _cooldown[i] == 0.0 and (c.wheel_load > k.static_total * 3.0 or hard_stop > k.static_total * 2.0):
			var energy := 0.5 * k.unsprung * wheel_v * wheel_v + hard_stop * 0.01
			events.append({ "corner": c.corner, "type": "impact", "intensity": minf(1.0, energy / part["strength"]) })
			if input.damage:
				SuspensionData.damage_corner(saved, i, energy, side)
				damaged = true
			_cooldown[i] = 0.15
	steering["leftWheelAngle"] = corners[0].steering_angle
	steering["rightWheelAngle"] = corners[1].steering_angle
	# Damage bends geometry mid-step: refresh the flattened parameters.
	if damaged:
		_cache_params()


## Isolated 3-DOF chassis using the same corner forces as the runtime adapter.
func preview(dt: float, longitudinal := 0.0, lateral := 0.0, steering_ := 0.0, roads: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	events.clear()
	_cache_params()
	var span := minf(0.1, dt)
	var steps := ceili(span * 1200.0)
	var h := span / steps
	var b := baseline
	var p := pose
	var sprung: float = b["mass"]
	for c in saved["setup"]["corners"]:
		sprung -= c["unsprungMass"]
	var input := StepInput.new()
	input.roads = roads
	input.steering = steering_
	var xs: PackedFloat64Array = []
	var zs: PackedFloat64Array = []
	for i in 4:
		xs.append((1.0 if i % 2 == 1 else -1.0) * b["track"] / 2.0)
		zs.append(b["wheelbase"] * (1.0 - b["frontWeight"]) if i < 2 else -b["wheelbase"] * b["frontWeight"])
	for n in steps:
		for i in 4:
			input.mounts[i] = p["heave"] - p["pitch"] * zs[i] + p["roll"] * xs[i]
			input.velocities[i] = p["velocity"] - p["pitchVelocity"] * zs[i] + p["rollVelocity"] * xs[i]
		_integrate(h, input)
		var vertical := -sprung * G
		var pitch: float = -longitudinal * b["mass"] * b["cgHeight"]
		var roll: float = lateral * b["mass"] * b["cgHeight"]
		for i in 4:
			vertical += corners[i].suspension_force
			pitch -= corners[i].suspension_force * zs[i]
			roll += corners[i].suspension_force * xs[i]
		p["velocity"] += vertical / sprung * h
		p["pitchVelocity"] += pitch / (sprung * b["wheelbase"] * b["wheelbase"] / 8.0) * h
		p["rollVelocity"] += roll / (sprung * b["track"] * b["track"] / 5.0) * h
		p["heave"] += p["velocity"] * h
		p["pitch"] += p["pitchVelocity"] * h
		p["roll"] += p["rollVelocity"] * h
