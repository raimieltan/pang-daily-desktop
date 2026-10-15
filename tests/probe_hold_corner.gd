extends SceneTree
## Steady cornering on keys: hold one direction 4 s at constant speed, report settled lateral g,
## rack angle and front/rear tire slip. Measures how much grip the keyboard assist leaves unused.
## `godot --headless --path . -s res://tests/probe_hold_corner.gd -- [preset] [steeringKey=value ...]`

const DT := 1.0 / 120.0

var _steering := {}


func _initialize() -> void:
	var preset := "fwd_worn_sedan"
	for arg in OS.get_cmdline_user_args():
		if "=" in arg:
			_steering[arg.get_slice("=", 0)] = float(arg.get_slice("=", 1))
		else:
			preset = arg
	print("preset %s %s" % [preset, _steering])
	print("  kph | rack° | frontSlip° | rearSlip° | latG settled | latG peak")
	for kph in [40.0, 60.0, 80.0, 110.0, 140.0]:
		_hold(preset, kph)
	quit(0)


func _hold(preset: String, kph: float) -> void:
	var model := HandlingModel.new(HandlingPresets.resolve(preset))
	(model.config["mechanical"]["steering"] as Dictionary).merge(_steering, true)
	var contact := VehicleTypes.AxleContact.grounded()
	var target := kph / 3.6
	model.sync_motion(target, 0.0, 0.0)
	var peak := 0.0
	var settled := 0.0
	var rack := 0.0
	var fs := 0.0
	var rs := 0.0
	var n_total := roundi(4.0 / DT)
	for n in n_total:
		var s := model.state
		var throttle := clampf((target - s.vx) * 0.6 + 0.3, 0.0, 1.0)
		model.step(DT, VehicleTypes.DriverInput.make(throttle, 0.0, 1.0, 0.0, "keyboard"), contact)
		s = model.state
		var g := absf(s.vx * s.yaw_rate) / 9.81
		peak = maxf(peak, g)
		if n > n_total - 120:
			settled += g / 120.0
			rack += absf(s.steer_angle) / 120.0
			fs += absf(model.mechanics.wheels[0].slip_angle) / 120.0
			rs += absf(model.mechanics.wheels[2].slip_angle) / 120.0
	print("  %3d | %5.1f | %10.1f | %9.1f | %12.2f | %9.2f" % [kph, rack / SimMath.DEG, fs / SimMath.DEG, rs / SimMath.DEG, settled, peak])
