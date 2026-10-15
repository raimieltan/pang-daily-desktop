class_name FourWheelDynamics
extends RefCounted
## Four-wheel planar rigid-body dynamics. Only tire forces and drag accelerate the chassis.
## Body axes: x forward, y right; right yaw positive. SI units.
## Port of `src/game/vehicles/handling/FourWheelDynamics.ts`; keep the two in step.

const G := 9.81
const DEG := PI / 180.0
## Where the combined-slip saturation curve peaks: demand ≈ 2.1 gives ≈ 0.917 of the grip cap.
const PEAK_DEMAND := 2.1
const PEAK_SATURATION := 0.917


class WheelState:
	var angular_velocity := 0.0
	var wheel_rpm := 0.0
	var vertical_load := 0.0
	var longitudinal_velocity := 0.0
	var lateral_velocity := 0.0
	var slip_ratio := 0.0
	var slip_angle := 0.0
	var longitudinal_force := 0.0
	var lateral_force := 0.0
	var max_longitudinal_grip := 0.0
	var max_lateral_grip := 0.0
	## Combined slip demand against the tire's peak (1 = at the brush curve peak, more = sliding).
	var demand := 0.0
	var surface_grip := 1.0
	var temperature := 25.0
	var wear := 0.0
	var pressure := 32.0
	var is_grounded := false
	var is_sliding := false
	var is_spinning := false
	var is_locked := false
	var slip_energy := 0.0
	var grip_recovery := 1.0
	var suspension_load := 0.0

	func clear() -> void:
		var keep_t := temperature
		var keep_w := wear
		angular_velocity = 0.0; wheel_rpm = 0.0; vertical_load = 0.0
		longitudinal_velocity = 0.0; lateral_velocity = 0.0; slip_ratio = 0.0; slip_angle = 0.0
		longitudinal_force = 0.0; lateral_force = 0.0; max_longitudinal_grip = 0.0; max_lateral_grip = 0.0; demand = 0.0
		surface_grip = 1.0; pressure = 32.0
		is_grounded = false; is_sliding = false; is_spinning = false; is_locked = false
		slip_energy = 0.0; grip_recovery = 1.0; suspension_load = 0.0
		temperature = keep_t; wear = keep_w


## Body-frame force per corner averaged over the substeps: x = forward, y = right (N).
var applied_forces: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var wheels: Array[WheelState] = []
var assistance := DriverAssistance.new()
var detector := DriverAssistance.DriftDetector.new()
# Powertrain telemetry.
var engine_rpm := 850.0
var gear := 1
var clutch := 0.0
var axle_torque := 0.0
var differential_lock := 0.0

var _model  # HandlingModel (untyped to avoid a cyclic class reference)
var _initialized := false
var _reverse_timer := 0.0
var _shift_timer := 0.0
var _upshifting := false
var _front_transfer := 0.0
var _rear_transfer := 0.0
var _roll_velocity := 0.0
var _pitch_velocity := 0.0
var _previous_handbrake := 0.0


func _init(model) -> void:
	_model = model
	for i in 4:
		wheels.append(WheelState.new())


func reset() -> void:
	for w in wheels:
		w.clear()
	assistance.reset()
	detector.drifting = false
	engine_rpm = 850.0; gear = 1; clutch = 0.0; axle_torque = 0.0; differential_lock = 0.0
	_initialized = false
	_reverse_timer = 0.0; _shift_timer = 0.0; _front_transfer = 0.0; _rear_transfer = 0.0
	_roll_velocity = 0.0; _pitch_velocity = 0.0; _previous_handbrake = 0.0


## Opposite wheel torques conserve total axle torque and dissipate relative rotation.
static func differential_torques(left: float, right: float, total: float, diff: Dictionary, inertia: float, dt: float) -> Vector2:
	var difference := left - right
	var type: String = diff["type"]
	var strength: float = 0.0 if type == "open" else (1.0 if type == "welded" else diff["lock"])
	var viscous := difference * (2000.0 if type == "welded" else 120.0 * strength)
	var requested: float = viscous + SimMath.sign_(difference) * diff["preloadNm"] * strength
	# Do not overshoot equal wheel speed in one substep (coupling cannot add energy).
	var limit := absf(difference) * inertia / (2.0 * dt)
	var correction := SimMath.clamp_(requested, -limit, limit)
	return Vector2(total / 2.0 - correction, total / 2.0 + correction)


## Body pitch and roll (rad; +pitch nose down, +roll right side up) from the carried load transfer.
func body_attitude() -> Vector2:
	var c: Dictionary = _model.config
	var p: Dictionary = c["mechanical"]
	var s: VehicleTypes.HandlingState = _model.state
	var L: float = c["chassis"]["wheelbaseM"]
	var a: float = L * (1.0 - c["chassis"]["frontWeight"])
	var b: float = L - a
	var track: float = c["chassis"]["trackWidthM"]
	var weight: float = c["chassis"]["massKg"] * G
	var sus: Dictionary = p["suspension"]
	var pitch_stiffness: float = 2.0 * (sus["frontSpring"] * a * a + sus["rearSpring"] * b * b)
	var roll_stiffness: float = (sus["frontSpring"] + sus["frontAntiRoll"] + sus["rearSpring"] + sus["rearAntiRoll"]) * track * track / 2.0
	return Vector2(s.load_shift * weight * L / pitch_stiffness, s.lateral_load_shift * weight * track / roll_stiffness)


func step(dt: float, input: VehicleTypes.DriverInput, contact: VehicleTypes.AxleContact) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	# Bounded substeps keep the stiff wheel/contact solve consistent at 30–240 Hz.
	var span := minf(dt, 0.25)
	var steps := ceili(span / (1.0 / 600.0))
	var h := span / steps
	for f in 4:
		applied_forces[f] = Vector2.ZERO
	for i in steps:
		_integrate(h, input, contact)
		for j in 4:
			var corner: VehicleTypes.CornerForces = _model.corners[j]
			var co := cos(corner.steer_angle)
			var si := sin(corner.steer_angle)
			applied_forces[j] += Vector2(corner.fx * co - corner.fy * si, corner.fx * si + corner.fy * co) / steps


# Brush-style combined slip: longitudinal force at wheel speed `omega` (the bisection's inner function).
static func _fx_at(omega: float, radius: float, u: float, peak_slip_ratio: float, sy: float, max_long: float, breakaway: float) -> float:
	var kappa := (omega * radius - u) / maxf(absf(u), 1.0)
	var sx := kappa / peak_slip_ratio
	var demand := sqrt(sx * sx + sy * sy)
	var saturation := (1.0 - exp(-1.5 * demand)) * (1.0 - breakaway * SimMath.smoothstep_(1.0, 5.0, demand))
	var scale := saturation / demand if demand > 1e-9 else 1.5
	return max_long * sx * scale


func _integrate(dt: float, input: VehicleTypes.DriverInput, contact: VehicleTypes.AxleContact) -> void:
	var model = _model
	var c: Dictionary = model.config
	var p: Dictionary = c["mechanical"]
	var s: VehicleTypes.HandlingState = model.state
	var diag: VehicleTypes.HandlingDiagnostics = model.diagnostics
	var chassis: Dictionary = c["chassis"]
	var mass: float = chassis["massKg"]
	var L: float = chassis["wheelbaseM"]
	var front_weight: float = chassis["frontWeight"]
	var a := L * (1.0 - front_weight)
	var b := L - a
	var half_track: float = chassis["trackWidthM"] / 2.0
	var p_tire: Dictionary = p["tire"]
	var p_sus: Dictionary = p["suspension"]
	var e: Dictionary = p["engine"]
	var gear_ratios: Array = e["gearRatios"]
	var wheel_radius: float = p["wheel"]["radiusM"]
	var wheel_inertia: float = p["wheel"]["inertia"]
	var speed := sqrt(s.vx * s.vx + s.vy * s.vy)
	var yaw := s.yaw_rate
	var has_suspension := not contact.suspension.is_empty()
	var tires: Array = model.tires
	var grounded: Array[bool] = [false, false, false, false]
	for i in 4:
		var t: VehicleTypes.CornerTire = tires[i]
		var touching: bool = contact.wheels[i] if not contact.wheels.is_empty() else (contact.front if i < 2 else contact.rear) > 0.0
		grounded[i] = t.installed and not t.raised and touching
	if not _initialized:
		for i in 4:
			wheels[i].angular_velocity = (s.vx - yaw * (-half_track if i % 2 == 0 else half_track)) / wheel_radius
		_initialized = true
		# A teleported moving spawn starts in the matching gear, without a spurious clutch kick.
		while gear < gear_ratios.size() and absf(s.vx) / wheel_radius * gear_ratios[gear - 1] * e["finalDrive"] * 60.0 / TAU > e["redlineRpm"] * 0.75:
			gear += 1
		engine_rpm = maxf(e["idleRpm"], absf(s.vx) / wheel_radius * gear_ratios[gear - 1] * e["finalDrive"] * 60.0 / TAU)
	var raw_throttle := SimMath.clamp_(input.throttle, 0.0, 1.0)
	var raw_brake := SimMath.clamp_(input.brake, 0.0, 1.0)
	var low_speed: Dictionary = c["lowSpeed"]
	var engage_below: float = low_speed["reverseEngageBelowKmh"] / 3.6
	var wants_reverse := not s.reversing and raw_brake > 0.5 and raw_throttle < 0.1 and speed < engage_below
	_reverse_timer = _reverse_timer + dt if wants_reverse else 0.0
	if wants_reverse and _reverse_timer >= low_speed["reverseDelaySeconds"]:
		s.reversing = true
		_reverse_timer = 0.0
	if s.reversing and raw_throttle > 0.5 and raw_brake < 0.1 and speed < engage_below:
		s.reversing = false
	var rear_slip := (absf(wheels[2].slip_ratio) + absf(wheels[3].slip_ratio)) / 2.0
	var hb: Dictionary = c["handbrake"]
	var pedals: Dictionary = (c["pedals"] as Dictionary).duplicate()
	pedals["handbrakeRise"] = hb["engageSmoothing"]
	pedals["handbrakeFall"] = hb["releaseSmoothing"]
	assistance.step(dt, input.steer,
		0.0 if not input.engine_available else (raw_brake if s.reversing else raw_throttle),
		raw_throttle if s.reversing else raw_brake,
		input.handbrake if hb["enabled"] else 0.0, input.device,
		{ "vx": s.vx, "vy": s.vy, "yaw_rate": yaw, "rear_slip_ratio": rear_slip, "front_axle_m": a, "rear_axle_m": b }, p, pedals)
	var controls := assistance
	if not input.engine_available:
		controls.throttle_assisted = 0.0
		controls.throttle_filtered = 0.0
	s.steer_angle = controls.actual_steering
	s.throttle = controls.throttle_assisted
	s.brake = controls.brake
	s.handbrake = controls.handbrake
	if _previous_handbrake > s.handbrake:
		for w in [wheels[2], wheels[3]]:
			w.grip_recovery = minf(w.grip_recovery, 1.0 - _previous_handbrake)
	_previous_handbrake = s.handbrake

	# Damped suspension response to inertial load transfer (used only without a suspension solver).
	var height := maxf(0.1, chassis["cgHeightM"] + p_sus["rideHeightOffsetM"])
	var total_weight := mass * G
	var front_spring: float = p_sus["frontSpring"]
	var rear_spring: float = p_sus["rearSpring"]
	var damping: float = p_sus["damping"]
	var spring := (front_spring + rear_spring) / mass
	if not has_suspension:
		var pitch_target := SimMath.clamp_(-s.long_accel * height / (G * L), -0.35, 0.35)
		_pitch_velocity += ((pitch_target - s.load_shift) * spring - 2.0 * damping * sqrt(spring) * _pitch_velocity) * dt
		s.load_shift += _pitch_velocity * dt
		var roll_target := SimMath.clamp_(s.lat_accel * height / (G * chassis["trackWidthM"]), -0.48, 0.48)
		_roll_velocity += ((roll_target - s.lateral_load_shift) * spring - 2.0 * damping * sqrt(spring) * _roll_velocity) * dt
		s.lateral_load_shift += _roll_velocity * dt
	var front_stiffness: float = front_spring + p_sus["frontAntiRoll"]
	var rear_stiffness: float = rear_spring + p_sus["rearAntiRoll"]
	var roll_front := front_stiffness / (front_stiffness + rear_stiffness)
	var front_load := total_weight * SimMath.clamp_(front_weight + s.load_shift, 0.05, 0.95)
	var rear_load := total_weight - front_load
	_front_transfer = SimMath.clamp_(total_weight * s.lateral_load_shift * roll_front, -front_load / 2.0, front_load / 2.0)
	_rear_transfer = SimMath.clamp_(total_weight * s.lateral_load_shift * (1.0 - roll_front), -rear_load / 2.0, rear_load / 2.0)
	var loads: Array[float] = []
	if has_suspension:
		for i in 4:
			var corner: SuspensionSolver.CornerState = contact.suspension[i]
			loads.append(corner.wheel_load)
			grounded[i] = grounded[i] and corner.is_grounded
		s.load_shift = (loads[0] + loads[1]) / total_weight - front_weight
		s.lateral_load_shift = (loads[0] + loads[2] - loads[1] - loads[3]) / (2.0 * total_weight)
	else:
		loads = [front_load / 2.0 + _front_transfer, front_load / 2.0 - _front_transfer,
			rear_load / 2.0 + _rear_transfer, rear_load / 2.0 - _rear_transfer]
	var drivetrain: String = c["drive"]["drivetrain"]
	var front_drive := 1.0 if drivetrain == "FWD" else (0.4 if drivetrain == "AWD" else 0.0)
	var driven_speed := (wheels[0].angular_velocity + wheels[1].angular_velocity) / 2.0 * front_drive \
		+ (wheels[2].angular_velocity + wheels[3].angular_velocity) / 2.0 * (1.0 - front_drive)
	var driven_slip := (absf(wheels[0].slip_ratio) + absf(wheels[1].slip_ratio)) / 2.0 if front_drive == 1.0 else rear_slip
	# TCS acts around the tire's peak slip, watching the worst driven wheel.
	var peak_slip: float = p_tire["peakSlipRatio"]
	var worst_slip := -INF
	for i in 4:
		if (front_drive > 0.0) if i < 2 else (front_drive < 1.0):
			worst_slip = maxf(worst_slip, absf(wheels[i].slip_ratio))
	var tcs: String = p["tcs"]
	var traction_trim := 0.0
	if tcs == "on":
		traction_trim = SimMath.smoothstep_(peak_slip * 0.6, peak_slip * 1.6, worst_slip) * 0.95
	elif tcs != "off":
		traction_trim = SimMath.smoothstep_(peak_slip, peak_slip * 4.0, worst_slip) * 0.35
	var throttle := s.throttle * (1.0 - traction_trim)
	# ESC requests one caliper and trims torque. It cannot directly produce a yaw acceleration.
	var wanted_yaw := s.vx * tan(s.steer_angle) / L
	var yaw_error := wanted_yaw - yaw
	# Dead band: ordinary lane corrections must not trim power, only a real yaw mismatch does.
	var esc_brake := SimMath.clamp_((absf(yaw_error) - 0.12) * 0.45, 0.0, 0.4) if (p["esc"] and speed > 5.0) else 0.0
	throttle *= 1.0 - esc_brake
	_shift_timer = maxf(0.0, _shift_timer - dt)
	gear = clampi(gear, 1, gear_ratios.size())
	var final_drive: float = e["finalDrive"]
	var redline: float = e["redlineRpm"]
	if not s.reversing and _shift_timer == 0.0 and driven_slip < 0.3:
		var rpm: float = absf(driven_speed) * gear_ratios[gear - 1] * final_drive * 60.0 / TAU
		if rpm > redline * 0.9 and gear < gear_ratios.size():
			gear += 1; _shift_timer = e["shiftSeconds"]; _upshifting = true
		elif rpm < 1800.0 and gear > 1:
			gear -= 1; _shift_timer = e["shiftSeconds"]; _upshifting = false
	var ratio: float = (-e["reverseRatio"] if s.reversing else gear_ratios[gear - 1]) * final_drive
	var engine_omega := engine_rpm * TAU / 60.0
	var auto_clutch := SimMath.clamp_(speed / 4.0 + throttle, 0.0, 1.0) * (0.0 if _shift_timer > 0.0 else 1.0)
	# The automatic clutch opens with the driven-axle handbrake to avoid stalling the engine.
	clutch = auto_clutch * (1.0 - maxf(SimMath.clamp_(input.clutch, 0.0, 1.0), s.handbrake * (1.0 - front_drive)))
	var clutch_torque: float = e["clutchTorqueNm"]
	var coupling := SimMath.clamp_((engine_omega - driven_speed * ratio) * 6.0, -clutch_torque, clutch_torque) * clutch
	var rpm_fraction: float = engine_rpm / e["peakTorqueRpm"]
	var torque_curve := SimMath.clamp_(1.0 - 0.22 * (rpm_fraction - 1.0) * (rpm_fraction - 1.0), 0.45, 1.0)
	var limiter := 1.0 - SimMath.smoothstep_(redline - 150.0, redline, engine_rpm)
	var idle_rpm: float = e["idleRpm"]
	var torque_nm: float = e["torqueNm"]
	var idle_torque := SimMath.clamp_((idle_rpm - engine_rpm) * 0.5, 0.0, torque_nm * 0.4)
	# Off boost a small turbo makes ~60% torque; it spools in on the way to peak torque.
	var boost := 0.6 + 0.4 * SimMath.smoothstep_(e["boostRpm"], e["peakTorqueRpm"], engine_rpm) if e.has("boostRpm") else 1.0
	var engine_torque := 0.0 if not input.engine_available else throttle * torque_nm * torque_curve * boost * limiter + idle_torque
	# Closed-throttle pumping loss is the engine braking; it reaches the wheels only through the clutch.
	var friction_torque := 8.0 + engine_omega * (0.025 + 0.05 * (1.0 - throttle))
	engine_rpm = SimMath.clamp_((engine_omega + (engine_torque - coupling - friction_torque) / e["inertia"] * dt) * 60.0 / TAU, 0.0, redline + 200.0)
	# Rev-matched shifts: the engine settles to the new gear while the clutch is open.
	var rev_match: String = p.get("revMatch", "off")
	if (rev_match == "all" or (rev_match == "upshift" and _upshifting)) and _shift_timer > 0.0 and not s.reversing:
		var matched := absf(driven_speed * ratio) * 60.0 / TAU
		engine_rpm += (maxf(idle_rpm, matched) - engine_rpm) * (1.0 - exp(-dt * 4.0 / e["shiftSeconds"]))
	var axle: float = coupling * ratio * e["efficiency"]
	if not input.engine_available:
		axle = 0.0
	axle_torque = axle
	var diff: Dictionary = p["differential"]
	differential_lock = 1.0 if diff["type"] == "welded" else (0.0 if diff["type"] == "open" else diff["lock"])
	var front_t := differential_torques(wheels[0].angular_velocity, wheels[1].angular_velocity, axle * front_drive, diff, wheel_inertia, dt)
	var rear_t := differential_torques(wheels[2].angular_velocity, wheels[3].angular_velocity, axle * (1.0 - front_drive), diff, wheel_inertia, dt)
	# Non-driven axles have no differential coupling.
	var torques: Array[float] = [front_t.x if front_drive > 0.0 else 0.0, front_t.y if front_drive > 0.0 else 0.0,
		rear_t.x if front_drive < 1.0 else 0.0, rear_t.y if front_drive < 1.0 else 0.0]

	var tires_cfg: Dictionary = c["tires"]
	var brakes: Dictionary = c["brakes"]
	var front_bias: float = brakes["frontBias"]
	var brake_decel: float = brakes["decelerationMps2"]
	var rear_brake: float = hb["rearBrakeMps2"]
	var rolling_mps2: float = c["drive"]["rollingResistanceMps2"]
	var surface: float = model.surface_grip
	var overheat: float = p_tire["overheatC"]
	var load_exponent: float = p_tire["loadExponent"]
	var relaxation: float = p_tire["relaxationSeconds"]
	var recovery: float = p_tire["recoverySeconds"]
	var breakaway: float = p_tire.get("breakaway", 0.22)
	var abs_on: bool = p["abs"]
	var fx_total := 0.0
	var fy_total := 0.0
	var moment := 0.0
	for i in 4:
		var w := wheels[i]
		var geometry: SuspensionSolver.CornerState = contact.suspension[i] if has_suspension else null
		var front := i < 2
		var left := i % 2 == 0
		var x: float = geometry.wheel_position.z if geometry else (a if front else -b)
		var y: float = geometry.wheel_position.x if geometry else (-half_track if left else half_track)
		var radius: float = geometry.radius if geometry else wheel_radius
		var toe: float = p_sus["toeDeg"] * DEG * (1.0 if left else -1.0)
		var steer: float = geometry.heading if geometry else ((s.steer_angle if front else 0.0) + toe)
		var co := cos(steer)
		var si := sin(steer)
		var corner_long := s.vx - yaw * y
		var corner_lat := s.vy + yaw * x
		var u := corner_long * co + corner_lat * si
		var v := -corner_long * si + corner_lat * co
		var tire: VehicleTypes.CornerTire = tires[i]
		var on_ground := grounded[i]
		w.is_grounded = on_ground
		w.vertical_load = loads[i] if on_ground else 0.0
		w.suspension_load = loads[i]
		w.longitudinal_velocity = u
		w.lateral_velocity = v
		w.slip_angle = atan2(v, maxf(absf(u), 0.5))
		w.surface_grip = surface * tire.surface_grip
		w.pressure = tire.pressure_psi
		w.grip_recovery = SimMath.move_toward_(w.grip_recovery, 1.0, dt / recovery)
		var reference := total_weight * (front_weight if front else 1.0 - front_weight) / 2.0
		# Only overheating costs grip here; the cold side belongs to the tire product (compounds.ts).
		var heat_grip := 1.0 - 0.4 * SimMath.smoothstep_(overheat, overheat + 70.0, w.temperature)
		var camber: float
		if geometry:
			camber = geometry.road_camber if geometry.has_road_camber else geometry.camber
		else:
			camber = p_sus["camberDeg"] * DEG
		var camber_grip := maxf(0.35, cos(camber * 2.5))
		var cap := 0.0
		if on_ground:
			cap = (tires_cfg["frontGrip"] if front else tires_cfg["rearGrip"]) * surface * tire.grip \
				* reference * pow(w.vertical_load / reference, load_exponent) * heat_grip * (1.0 - 0.65 * w.wear) * camber_grip
		w.max_lateral_grip = cap
		w.max_longitudinal_grip = cap * tire.longitudinal_grip * maxf(0.35, cos(camber * 4.0))
		var peak_angle: float = (tires_cfg["frontPeakSlipDeg"] if front else tires_cfg["rearPeakSlipDeg"]) * DEG * tire.slip_scale
		var sy := tan(SimMath.clamp_(w.slip_angle, -1.5, 1.5)) / tan(peak_angle) + (camber * (1.0 if left else -1.0) * 0.55 if geometry else 0.0)
		var service := s.brake * mass * brake_decel * radius * (front_bias if front else 1.0 - front_bias) / 2.0
		var hand := s.handbrake * mass * rear_brake * radius / 2.0 if not front else 0.0
		var esc := esc_brake * mass * G * radius if (front and ((yaw_error > 0.0) != left)) else 0.0
		var abs_scale := 0.15 if (abs_on and w.slip_ratio < -0.16 and absf(u) > 2.0) else 1.0
		var rubbing := geometry != null and geometry.rubbing
		var rolling := ((tire.rolling_resistance + (0.12 if rubbing else 0.0)) * loads[i] + mass * rolling_mps2 / 4.0) * radius if on_ground else 0.0
		var brake_torque := (service + esc) * abs_scale + hand + rolling
		var free := w.angular_velocity + torques[i] / wheel_inertia * dt
		var max_long := w.max_longitudinal_grip
		# Implicit angular momentum + tire reaction, with Coulomb brake holding at zero:
		# permits genuine wheel lock and stationary burnouts without numerical chatter.
		var brake_step := brake_torque / wheel_inertia * dt
		var react := radius / wheel_inertia * dt
		var span := (absf(torques[i]) + brake_torque + max_long * radius) / wheel_inertia * dt + 1.0
		var lo := minf(0.0, free) - span
		var hi := maxf(0.0, free) + span
		for n in 24:
			var mid := (lo + hi) / 2.0
			var response := SimMath.move_toward_(free - _fx_at(mid, radius, u, peak_slip, sy, max_long, breakaway) * react, 0.0, brake_step)
			if mid - response > 0.0:
				hi = mid
			else:
				lo = mid
		w.angular_velocity = (lo + hi) / 2.0
		var kappa := (w.angular_velocity * radius - u) / maxf(absf(u), 1.0)
		var sx := kappa / peak_slip
		var demand := sqrt(sx * sx + sy * sy)
		var saturation := (1.0 - exp(-1.5 * demand)) * (1.0 - breakaway * SimMath.smoothstep_(1.0, 5.0, demand))
		var scale := saturation / demand if demand > 1e-9 else 1.5
		var force_fx := max_long * sx * scale
		var force_fy := -cap * sy * scale
		var recovery_time := relaxation + (1.0 - w.grip_recovery) * recovery
		# Tire carcass relaxation; after release lateral force rebuilds rather than snapping.
		w.lateral_force += (force_fy - w.lateral_force) * (1.0 - exp(-dt / recovery_time))
		w.longitudinal_force = force_fx
		w.demand = demand
		if not on_ground:
			w.lateral_force = 0.0
			w.longitudinal_force = 0.0
		# Transients must still respect the current friction ellipse (landing/load changes included).
		var lat_use := w.lateral_force / cap if cap > 0.0 else 0.0
		var long_use := w.longitudinal_force / max_long if max_long > 0.0 else 0.0
		var use := sqrt(lat_use * lat_use + long_use * long_use)
		if use > 1.0:
			w.lateral_force /= use
			w.longitudinal_force /= use
		w.slip_ratio = kappa
		w.wheel_rpm = w.angular_velocity * 60.0 / TAU
		w.is_locked = on_ground and absf(u) > 1.0 and absf(w.angular_velocity * radius) < 0.15
		w.is_spinning = on_ground and absf(w.angular_velocity * radius) > absf(u) + 2.0
		w.is_sliding = on_ground and (absf(w.slip_angle) > peak_angle or absf(w.slip_ratio) > peak_slip)
		w.slip_energy = absf(w.longitudinal_force * (w.angular_velocity * radius - u)) + absf(w.lateral_force * v) if on_ground else 0.0
		w.temperature += (w.slip_energy / p_tire["heatCapacity"] - (w.temperature - p_tire["ambientC"]) * p_tire["coolingRate"] * (1.0 + speed / 30.0)) * dt
		w.wear = SimMath.clamp_(w.wear + w.slip_energy * p_tire["wearPerJoule"] * (1.0 + SimMath.smoothstep_(100.0, 160.0, w.temperature) * 3.0) * dt, 0.0, 1.0)
		var fx := w.longitudinal_force * co - w.lateral_force * si
		var fy := w.longitudinal_force * si + w.lateral_force * co
		fx_total += fx
		fy_total += fy
		moment += x * fy - y * fx
		var out: VehicleTypes.CornerForces = model.corners[i]
		out.grounded = on_ground
		out.normal_load_n = w.vertical_load
		out.fx = w.longitudinal_force
		out.fy = w.lateral_force
		out.drive_n = absf(torques[i]) / radius
		out.brake_n = (service + hand + esc) / radius
		out.rolling_n = rolling / radius
		out.cap_n = cap
		out.slip_angle = w.slip_angle
		out.slip_ratio = w.slip_ratio
		out.wheel_speed = w.angular_velocity * radius
		out.steer_angle = steer
	# Integrate forces in the inertial frame, then rotate back into the new body frame.
	# Exact frame rotation avoids the energy injection of sequential Coriolis Euler updates.
	var aero: float = c["drive"]["aeroDrag"]
	var ax := fx_total / mass - aero * speed * s.vx
	var ay := fy_total / mass - aero * speed * s.vy
	var inertia: float = mass * a * b * chassis["yawInertiaScale"]
	var next_yaw := yaw + moment / inertia * dt
	var rotation := next_yaw * dt
	var cos_r := cos(rotation)
	var sin_r := sin(rotation)
	var nvx := s.vx + ax * dt
	var nvy := s.vy + ay * dt
	s.vx = nvx * cos_r + nvy * sin_r
	s.vy = -nvx * sin_r + nvy * cos_r
	s.yaw_rate = next_yaw
	s.long_accel = ax
	s.lat_accel = ay
	s.lift_off = 0.0
	# Parking hold is a static brake constraint, never used while sliding or applying power.
	diag.held = grounded.has(true) and controls.throttle_raw == 0.0 and s.throttle < 0.01 \
		and sqrt(s.vx * s.vx + s.vy * s.vy) < 0.035 and absf(s.yaw_rate) < 0.015
	if diag.held:
		s.vx = 0.0
		s.vy = 0.0
		s.yaw_rate = 0.0
	diag.body_slip = atan2(s.vy, s.vx)
	diag.front_slip = (wheels[0].slip_angle + wheels[1].slip_angle) / 2.0
	diag.rear_slip = (wheels[2].slip_angle + wheels[3].slip_angle) / 2.0
	var st: Dictionary = p["steering"]
	diag.max_steer_angle = (st["roadAngleDeg"] + (st["driftAngleDeg"] - st["roadAngleDeg"]) * controls.drift_factor) * DEG
	diag.kinematic_yaw_rate = wanted_yaw
	diag.understeer = 1.0 - s.yaw_rate / wanted_yaw if absf(wanted_yaw) > 0.05 else 0.0
	# Share of the tire's peak force in use: 1 at the peak and above it while sliding (see the TS note).
	diag.front_grip_use = (_grip_use(wheels[0]) + _grip_use(wheels[1])) / 2.0
	diag.rear_grip_use = (_grip_use(wheels[2]) + _grip_use(wheels[3])) / 2.0
	diag.stability_yaw = 0.0
	diag.traction_cut = traction_trim
	diag.handbrake_effect = s.handbrake
	detector.step(speed * 3.6, diag.body_slip, s.yaw_rate, maxf(absf(diag.rear_slip), rear_slip))


static func _grip_use(w: WheelState) -> float:
	if w.max_lateral_grip <= 0.0:
		return 0.0
	var force := sqrt(w.longitudinal_force * w.longitudinal_force + w.lateral_force * w.lateral_force)
	return maxf(force / (w.max_lateral_grip * PEAK_SATURATION), minf(1.3, w.demand / PEAK_DEMAND))
