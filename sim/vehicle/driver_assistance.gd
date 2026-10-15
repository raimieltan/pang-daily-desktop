class_name DriverAssistance
extends RefCounted
## Stateful virtual driver. Outputs only rack and pedal requests, never chassis corrections.
## Port of `DriverAssistance` in `src/game/vehicles/handling/DriverAssistance.ts`.

const PROFILES := {
	"assisted": { "counter": 0.85, "trim": 0.30, "transition": 1.5 },
	"standard": { "counter": 0.78, "trim": 0.25, "transition": 1.4 },
	"simulation": { "counter": 0.40, "trim": 0.10, "transition": 1.15 },
	"raw": { "counter": 0.0, "trim": 0.0, "transition": 1.0 },
}

# Telemetry (read by the dynamics and debug HUD).
var steering_input := 0.0
var player_target := 0.0
var counter_target := 0.0
var final_target := 0.0
var actual_steering := 0.0
var steering_velocity := 0.0
var drift_factor := 0.0
var throttle_raw := 0.0
var throttle_filtered := 0.0
var throttle_assisted := 0.0
var brake := 0.0
var handbrake := 0.0
var left_hold_time := 0.0
var right_hold_time := 0.0

var _filtered_angle := 0.0
var _previous_intent := 0.0
var _transition_time := 0.0
var _grip_window := INF


func reset() -> void:
	steering_input = 0.0; player_target = 0.0; counter_target = 0.0; final_target = 0.0
	actual_steering = 0.0; steering_velocity = 0.0; drift_factor = 0.0
	throttle_raw = 0.0; throttle_filtered = 0.0; throttle_assisted = 0.0
	brake = 0.0; handbrake = 0.0; left_hold_time = 0.0; right_hold_time = 0.0
	_filtered_angle = 0.0; _previous_intent = 0.0; _transition_time = 0.0; _grip_window = INF


## `motion`: vx, vy, yaw_rate, rear_slip_ratio, front_axle_m, rear_axle_m.
## `pedals`: throttleRise, throttleFall, brakeRise, brakeFall, handbrakeRise, handbrakeFall.
func step(dt: float, steering: float, throttle: float, brake_in: float, handbrake_in: float, device: String,
		motion: Dictionary, config: Dictionary, pedals: Dictionary) -> void:
	var keyboard := device == "keyboard"
	var profile: Dictionary = PROFILES[config["assistance"]]
	var cs: Dictionary = config.get("counterSteer", {})
	var st: Dictionary = config["steering"]
	var vx: float = motion["vx"]
	var vy: float = motion["vy"]
	var yaw_rate: float = motion["yaw_rate"]
	var steer := SimMath.clamp_(steering, -1.0, 1.0)
	var speed := sqrt(vx * vx + vy * vy) * 3.6
	# Movement angle is right-positive, so a left-turn slide needs POSITIVE (right) countersteer.
	var angle := atan2(vy, vx)
	var angle_delta := atan2(sin(angle - _filtered_angle), cos(angle - _filtered_angle))
	_filtered_angle += angle_delta * (1.0 - exp(-dt / 0.07))
	# Wrap: the TS original lets this wind up past ±π when the car twitches near standstill, which
	# pins drift-factor at 1 for the rest of the run (twitchy keyboard authority, phantom countersteer).
	_filtered_angle = wrapf(_filtered_angle, -PI, PI)
	var forward_gate := SimMath.smoothstep_(3.0, 15.0, speed) * (1.0 if vx > 0.0 else 0.0)
	var predicted_angle := _filtered_angle - yaw_rate * 0.22
	var drift := SimMath.smoothstep_(cs.get("startAngleDeg", 5.0) * SimMath.DEG, cs.get("fullAngleDeg", 22.0) * SimMath.DEG,
		absf(predicted_angle)) * forward_gate
	var band_start: float = st.get("sensitivityStartKph", 35.0)
	var speed_t := SimMath.clamp_((speed - band_start) / maxf(1.0, st.get("sensitivityFullKph", 140.0) - band_start), 0.0, 1.0)
	var road_multiplier := SimMath.lerp_(1.0, st.get("highSpeedAuthority", 0.40) if keyboard else 0.75, speed_t)
	var authority := 1.0 if (device == "wheel" or device == "ai") else SimMath.lerp_(road_multiplier, 0.9, drift)
	var max_angle := SimMath.lerp_(st["roadAngleDeg"], st["driftAngleDeg"], drift) * SimMath.DEG
	var strength: float = cs.get("strength", profile["counter"])
	var counter_gain := strength if keyboard else (minf(0.3, strength) if device == "controller" else 0.0)
	# Front contact-patch direction includes yaw velocity (caster/self-aligning tendency).
	var front_direction := atan2(vy + motion["front_axle_m"] * yaw_rate, maxf(1.0, vx))
	var caster := SimMath.clamp_(config["suspension"]["casterDeg"] / 15.0, 0.0, 1.0) * 0.15
	var counter := SimMath.clamp_(SimMath.lerp_(_filtered_angle * cs.get("gain", 0.95) - yaw_rate * 0.35, front_direction, caster),
		-max_angle, max_angle) * counter_gain * drift
	var player := steer * max_angle * authority
	# Full opposed intent replaces the assist; agreeing input reinforces it.
	var target := SimMath.clamp_(player + counter * (1.0 - absf(steer) * (1.0 if player * counter < 0.0 else 0.35)), -max_angle, max_angle)
	# Grip-limited lock (Forza "normal steering"): at speed a key or stick asks for the angle that puts
	# the front tires at their useful slip, measured from where the front axle is really travelling,
	# never the whole rack. The window follows a slide, so countersteer is always reachable.
	if not keyboard and device != "controller":
		_grip_window = INF
	elif st.get("gripLimitedLock", false):
		# The handbrake is a request to rotate: a handbrake turn gets the whole rack.
		var gate := SimMath.smoothstep_(st.get("gripLockFromKph", 18.0), st.get("gripLockFullKph", 45.0), speed) * forward_gate \
			* (1.0 - maxf(handbrake, SimMath.clamp_(handbrake_in, 0.0, 1.0)))
		# front_peak_slip is where lateral force peaks (frontPeakSlipDeg is only the curve's knee, ~76% force).
		# Fast swaps are where a big window pendulums the rear, so it narrows above ~80 km/h, where
		# sweepers need little lock anyway.
		var slip_fraction := SimMath.lerp_(st.get("gripLockSlip", 0.7), st.get("gripLockSlipHighSpeed", 0.3),
			SimMath.smoothstep_(st.get("gripLockTaperFromKph", 80.0), st.get("gripLockTaperFullKph", 140.0), speed))
		var slip_window: float = motion.get("front_peak_slip", 14.5 * SimMath.DEG) * slip_fraction
		_grip_window = SimMath.lerp_(max_angle, slip_window, gate)
		target = SimMath.clamp_(target, front_direction - _grip_window, front_direction + _grip_window)
		# Yaw limiter: past the yaw rate the tires can hold on this path (mu*g/v) the rack backs out of
		# the turn instead of adding rotation, the steering half of a stability assist. mu is the tires'
		# live grip with a margin: a fixed, low mu bled lock out of every limit corner (heavy understeer).
		var grip_mu: float = motion.get("grip_mu", 0.0)
		if grip_mu < 0.3:
			grip_mu = st.get("gripLockMu", 0.85)
		var yaw_cap: float = grip_mu * st.get("yawLimitMargin", 1.1) * 9.81 / maxf(5.0, vx)
		var over := (absf(yaw_rate) - yaw_cap) / yaw_cap
		if over > 0.0 and target * yaw_rate > 0.0:
			target *= 1.0 - SimMath.clamp_(over * st.get("yawLimitGain", 4.0), 0.0, 1.0) * gate
	left_hold_time = left_hold_time + dt if steer < 0.0 else 0.0
	right_hold_time = right_hold_time + dt if steer > 0.0 else 0.0
	if keyboard and drift > 0.2 and steer * _previous_intent < 0.0:
		_transition_time = 0.25
	_transition_time = maxf(0.0, _transition_time - dt)
	if steer != 0.0:
		_previous_intent = steer
	var rack_rate: float = st["rackRate"]
	var rate := SimMath.lerp_(rack_rate, st.get("highSpeedRackRate", rack_rate * 3.2 / 7.0), speed_t)
	rate = SimMath.lerp_(rate, rack_rate * 0.6, drift)
	if steer == 0.0:
		rate = st["returnRate"]
	var hold := maxf(left_hold_time, right_hold_time)
	if keyboard and hold > 0.0 and hold < 0.1:
		rate *= 1.35
	if _transition_time > 0.0:
		rate *= profile["transition"]
	if device == "wheel" or device == "ai":
		rate = rack_rate
	elif keyboard and st.get("gripLimitedLock", false):
		# Keys are all-or-nothing: at speed the rack takes ~0.3 s to its (grip-limited) lock, like a
		# thumb rolling a stick, instead of snapping there in a tenth of a second.
		rate = minf(rate, SimMath.lerp_(rack_rate, st.get("keyboardHighSpeedRate", 2.5), speed_t))
	# Rates are normalized rack travel/sec. Acceleration and damping avoid instant reversals.
	var error := target - actual_steering
	var rack_speed := rate * max_angle * authority
	var velocity_target := SimMath.clamp_(error * 18.0, -rack_speed, rack_speed)
	steering_velocity = SimMath.move_toward_(steering_velocity, velocity_target,
		st["rackAcceleration"] * (authority * authority if keyboard else 1.0) * dt)
	var step_ := steering_velocity * dt
	if step_ * error >= 0.0 and absf(step_) >= absf(error):
		actual_steering = target
		steering_velocity = 0.0
	else:
		actual_steering = SimMath.clamp_(actual_steering + step_, -max_angle, max_angle)
	steering_input = steer; player_target = player; counter_target = counter; final_target = target; drift_factor = drift
	throttle_raw = SimMath.clamp_(throttle, 0.0, 1.0)
	throttle_filtered = SimMath.move_toward_(throttle_filtered, throttle_raw,
		(pedals["throttleRise"] if throttle_raw > throttle_filtered else pedals["throttleFall"]) * dt)
	var risk := maxf(SimMath.smoothstep_(0.35, 0.75, absf(motion["rear_slip_ratio"])),
		SimMath.smoothstep_(45.0 * SimMath.DEG, 90.0 * SimMath.DEG, absf(yaw_rate)) * forward_gate)
	var trim: float = profile["trim"] if keyboard else (minf(0.12, profile["trim"]) if device == "controller" else 0.0)
	# A digital W through a road corner acts like a feathered pedal; only a real rear slide hands full throttle back.
	var rear_angle := atan2(vy - yaw_rate * motion.get("rear_axle_m", 0.0), maxf(1.0, vx))
	var sliding := SimMath.smoothstep_(8.0 * SimMath.DEG, 16.0 * SimMath.DEG, absf(rear_angle)) * forward_gate
	var cornering := absf(actual_steering) / max_angle * (1.0 - sliding) * SimMath.smoothstep_(5.0, 20.0, speed) if keyboard else 0.0
	throttle_assisted = throttle_filtered * (1.0 - risk * trim) * (1.0 - config.get("throttleFeather", 0.0) * cornering)
	brake = SimMath.move_toward_(brake, SimMath.clamp_(brake_in, 0.0, 1.0),
		(pedals.get("brakeRise", 7.0) if brake_in > brake else pedals.get("brakeFall", 9.0)) * dt)
	handbrake = SimMath.move_toward_(handbrake, SimMath.clamp_(handbrake_in, 0.0, 1.0),
		(pedals.get("handbrakeRise", 12.0) if handbrake_in > handbrake else pedals.get("handbrakeFall", 18.0)) * dt)


## Presentation/telemetry only. Never consulted by the force integrator.
class DriftDetector:
	var drifting := false

	func step(speed_kph: float, angle: float, yaw_rate: float, rear_slip: float) -> bool:
		drifting = speed_kph > (12.0 if drifting else 15.0) \
			and absf(angle) > (4.0 if drifting else 8.0) * SimMath.DEG \
			and absf(yaw_rate) > (4.0 if drifting else 8.0) * SimMath.DEG \
			and absf(rear_slip) > (0.04 if drifting else 0.08)
		return drifting
