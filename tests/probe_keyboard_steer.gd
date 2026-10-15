extends SceneTree
## Keyboard steering feel, sim only (flat grounded contact): digital left/right swaps at road speeds.
## Prints per-speed peaks: rack angle, body slip, rear tire slip, yaw rate, lateral g, response time.
## `godot --headless --path . -s res://tests/probe_keyboard_steer.gd`

const DT := 1.0 / 120.0

var _steering := {}


func _initialize() -> void:
	var preset := "fwd_worn_sedan"
	# Args: [preset] [steeringKey=value ...], e.g. `-- fwd_worn_sedan gripLockSlip=1.0`.
	for arg in OS.get_cmdline_user_args():
		if "=" in arg:
			_steering[arg.get_slice("=", 0)] = float(arg.get_slice("=", 1))
		else:
			preset = arg
	print("preset %s %s" % [preset, _steering])
	print("  kph | rack° | bodySlip° | rearSlip° | yaw°/s | latG | t90 ms | spun | end kph")
	for kph in [50.0, 80.0, 110.0, 140.0]:
		_slalom(preset, kph)
	quit(0)


func _slalom(preset: String, kph: float) -> void:
	var model := HandlingModel.new(HandlingPresets.resolve(preset))
	(model.config["mechanical"]["steering"] as Dictionary).merge(_steering, true)
	var contact := VehicleTypes.AxleContact.grounded()
	var target := kph / 3.6
	model.sync_motion(target, 0.0, 0.0)
	# Hold right 1.2 s (step response), then swap left/right every 0.5 s, then let go.
	var script: Array = [[0.5, 0.0], [1.2, 1.0], [0.5, -1.0], [0.5, 1.0], [0.5, -1.0], [0.5, 1.0], [1.5, 0.0]]
	var rack := 0.0
	var body := 0.0
	var rear := 0.0
	var yaw_peak := 0.0
	var lat := 0.0
	var spun := false
	var t := 0.0
	var step_yaw: Array[float] = []
	for phase in script:
		for n in roundi(phase[0] / DT):
			var s := model.state
			var throttle := clampf((target - s.vx) * 0.6 + 0.3, 0.0, 1.0)
			model.step(DT, VehicleTypes.DriverInput.make(throttle, 0.0, phase[1], 0.0, "keyboard"), contact)
			s = model.state
			t += DT
			if t > 0.5 and t <= 1.7:
				step_yaw.append(absf(s.yaw_rate))
			var slip := absf(atan2(s.vy, maxf(1.0, s.vx)))
			spun = spun or slip > 30.0 * SimMath.DEG or s.vx < 3.0
			rack = maxf(rack, absf(s.steer_angle))
			body = maxf(body, slip)
			rear = maxf(rear, maxf(absf(model.mechanics.wheels[2].slip_angle), absf(model.mechanics.wheels[3].slip_angle)))
			yaw_peak = maxf(yaw_peak, absf(s.yaw_rate))
			lat = maxf(lat, absf(s.vx * s.yaw_rate) / 9.81)
	# Time for the step to reach 90% of its final yaw rate.
	var t90 := -1.0
	var final_yaw := step_yaw[step_yaw.size() - 1]
	for i in step_yaw.size():
		if step_yaw[i] >= final_yaw * 0.9:
			t90 = i * DT * 1000.0
			break
	print("  %3d | %5.1f | %9.1f | %9.1f | %6.0f | %4.2f | %6.0f | %4s | %5.0f" % [kph, rack / SimMath.DEG, body / SimMath.DEG,
		rear / SimMath.DEG, yaw_peak / SimMath.DEG, lat, t90, "YES" if spun else "no", model.state.vx * 3.6])
