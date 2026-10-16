extends RefCounted
## Turns the autopilot into a show-off for powerslide footage: a handbrake flick on the way into
## each corner, then power held on while the tail is out. The AI's pure-pursuit steering aims
## relative to the body, so with the rear stepped out it counter-steers on its own.
## Used as a DriveSession input filter; only the trailer captures use it.

var car: CarBody
var ai: AiDriver
var track: TrackData
## How sharply the plan must drop ahead (plan speed / current speed) to count as a corner.
var entry_ratio := 0.9
var look_m := 28.0
var flick_seconds := 0.5
var hold_throttle := 1.0
var min_kmh := 45.0
var _flick := 0.0
var _cooldown := 0.0


func _init(car_: CarBody, ai_: AiDriver, track_: TrackData) -> void:
	car = car_
	ai = ai_
	track = track_


func filter(input: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var speed := car.linear_velocity.length()
	var plan := ai._plan
	var ahead: float = plan[mini(ai._index + int(look_m / track.spacing), plan.size() - 1)]
	var slip := absf(car.model.diagnostics.body_slip)
	_cooldown -= dt
	if _flick <= 0.0 and _cooldown <= 0.0 and speed * 3.6 > min_kmh and ahead < speed * entry_ratio:
		_flick = flick_seconds
		_cooldown = 2.2
	if _flick > 0.0:
		_flick -= dt
		input.handbrake = 1.0
		input.brake = 0.0
		input.throttle = 0.4
	elif slip > deg_to_rad(6.0) and slip < deg_to_rad(55.0):
		input.brake = 0.0
		input.throttle = maxf(input.throttle, hold_throttle)
	return input
