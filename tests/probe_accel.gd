extends SceneTree
## Straight-line launch on a flat, grounded sim: 0-100 km/h, 0-400 m, top speed in 40 s.
## `godot --headless --path . -s res://tests/probe_accel.gd -- [preset ...]`

const DT := 1.0 / 120.0


func _initialize() -> void:
	var presets := OS.get_cmdline_user_args()
	if presets.is_empty():
		presets = ["awd_gsr", "fwd_worn_sedan"]
	for preset in presets:
		_launch(preset)
	quit(0)


func _launch(preset: String) -> void:
	var model := HandlingModel.new(HandlingPresets.resolve(preset))
	var contact := VehicleTypes.AxleContact.grounded()
	var t := 0.0
	var x := 0.0
	var t100 := -1.0
	var t400 := -1.0
	while t < 40.0:
		model.step(DT, VehicleTypes.DriverInput.make(1.0, 0.0, 0.0, 0.0, "keyboard"), contact)
		t += DT
		x += model.state.vx * DT
		if t100 < 0.0 and model.state.vx * 3.6 >= 100.0:
			t100 = t
		if t400 < 0.0 and x >= 400.0:
			t400 = t
	print("%-22s 0-100 %.2f s  400 m %.2f s  vmax %.0f km/h" % [preset, t100, t400, model.state.vx * 3.6])
