extends RefCounted
## The gearbox and reverse: the manual shifts one step per press through R, N, 1..n and never
## shifts by itself; reversing, the wheel turns the way the key asks.

var errors: Array[String] = []

const DT := 1.0 / 120.0


func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func _run(model: HandlingModel, seconds: float, throttle: float, brake: float, steer := 0.0, manual := false, shift := 0) -> void:
	var contact := VehicleTypes.AxleContact.grounded()
	for n in roundi(seconds / DT):
		var i := VehicleTypes.DriverInput.make(throttle, brake, steer, 0.0, "keyboard")
		i.manual = manual
		i.shift = shift if n == 0 else 0
		model.step(DT, i, contact)


func _gear(model: HandlingModel) -> String:
	var s := model.state
	return "R" if s.reversing else ("N" if s.neutral else str(model.mechanics.gear))


func test_manual_holds_its_gear_and_shifts_per_press() -> void:
	var m := HandlingModel.new(HandlingPresets.resolve("fwd_sport_hatch"))
	_run(m, 4.0, 1.0, 0.0, 0.0, true)
	_check(_gear(m) == "1", "manual stays in 1st at full throttle (got %s)" % _gear(m))
	_check(m.mechanics.engine_rpm > m.config["mechanical"]["engine"]["redlineRpm"] * 0.9, "manual 1st runs up to the limiter")
	_run(m, 0.5, 1.0, 0.0, 0.0, true, 1)
	_check(_gear(m) == "2", "O shifts up once (got %s)" % _gear(m))
	_run(m, 0.5, 1.0, 0.0, 0.0, true, 1)
	_check(_gear(m) == "3", "a second press shifts again (got %s)" % _gear(m))


func test_manual_refuses_an_over_revving_downshift() -> void:
	var m := HandlingModel.new(HandlingPresets.resolve("fwd_sport_hatch"))
	m.sync_motion(140.0 / 3.6, 0.0, 0.0)
	_run(m, 0.2, 0.5, 0.0, 0.0, true)
	var before := _gear(m)
	for k in 5:
		_run(m, 0.05, 0.5, 0.0, 0.0, true, -1)
	_check(_gear(m) != "1" and _gear(m) != "N", "no drop into 1st or neutral at 140 km/h (from %s got %s)" % [before, _gear(m)])


func test_manual_reverse_through_neutral_at_a_stop() -> void:
	var m := HandlingModel.new(HandlingPresets.resolve("fwd_sport_hatch"))
	_run(m, 0.2, 0.0, 0.0, 0.0, true, -1)
	_check(_gear(m) == "R", "from the spawn neutral, I selects reverse (got %s)" % _gear(m))
	_run(m, 2.0, 1.0, 0.0, 0.0, true)
	_check(m.state.vx < -2.0, "the throttle drives a manual backwards in R (vx %.1f)" % m.state.vx)
	_run(m, 2.0, 0.0, 1.0, 0.0, true)
	_run(m, 0.1, 0.0, 0.0, 0.0, true, 1)
	_check(_gear(m) == "N", "O from R is neutral (got %s)" % _gear(m))
	_run(m, 1.0, 1.0, 0.0, 0.0, true)
	_check(_gear(m) == "N" and absf(m.state.vx) < 1.0, "a chosen neutral holds under throttle")
	_run(m, 0.1, 0.0, 0.0, 0.0, true, 1)
	_check(_gear(m) == "1", "O from N is 1st (got %s)" % _gear(m))


func test_steering_follows_the_key_in_reverse() -> void:
	for preset in ["fwd_sport_hatch", "awd_gsr", "rwd_box_turbo"]:
		var m := HandlingModel.new(HandlingPresets.resolve(preset))
		_run(m, 0.3, 0.0, 0.0)
		_run(m, 1.3, 0.0, 1.0)
		_check(m.state.reversing and m.state.vx < -2.0, "%s: reversing on the brake" % preset)
		for steer in [1.0, -1.0]:
			_run(m, 0.4, 0.0, 1.0, steer)
			_check(m.state.steer_angle * steer > 20.0 * SimMath.DEG, "%s: reversing, steer %+.0f turns the rack that way (%.1f°)" % [preset, steer, rad_to_deg(m.state.steer_angle)])
		_run(m, 1.5, 0.0, 1.0, -1.0)
		_check(m.state.vx < 0.0, "%s: holding lock in reverse does not whip the car round" % preset)
		_check(m.state.vx > -26.0 / 3.6, "%s: reverse stays under its top speed (%.1f km/h)" % [preset, -m.state.vx * 3.6])
