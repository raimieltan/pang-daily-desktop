extends SceneTree
## Steering while reversing, sim only (flat grounded contact): stop, select reverse on the brake,
## back up holding right then left. Prints rack angle and yaw rate; both must follow the key.
## `godot --headless --path . -s res://tests/probe_reverse_steer.gd -- [preset] [keyboard|controller]`

const DT := 1.0 / 120.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var preset := args[0] if args.size() > 0 else "fwd_worn_sedan"
	var device := args[1] if args.size() > 1 else "keyboard"
	var model := HandlingModel.new(HandlingPresets.resolve(preset))
	var contact := VehicleTypes.AxleContact.grounded()
	var t := 0.0
	# Release, then brake to engage reverse and back up; steer right, then left.
	var script: Array = [[0.3, 0.0, 0.0], [1.3, 1.0, 0.0], [2.0, 1.0, 1.0], [2.0, 1.0, -1.0]]
	print("preset %s  device %s" % [preset, device])
	print("   t | rev | kph  | steer | rack° | yaw°/s | kappaF | kappaR | alphaF° | alphaR° | thr")
	for phase in script:
		for n in roundi(phase[0] / DT):
			model.step(DT, VehicleTypes.DriverInput.make(0.0, phase[1], phase[2], 0.0, device), contact)
			t += DT
			if n % 30 == 29:
				var s := model.state
				var w: Array = model.mechanics.wheels
				print("%4.1f | %s | %5.1f | %4.1f | %5.1f | %6.1f | %6.2f | %6.2f | %6.1f | %6.1f | %4.2f" % [t, "R" if s.reversing else "-",
					s.vx * 3.6, phase[2], rad_to_deg(s.steer_angle), rad_to_deg(s.yaw_rate), w[0].slip_ratio, w[2].slip_ratio,
					rad_to_deg(w[0].slip_angle), rad_to_deg(w[2].slip_angle), s.throttle])
	quit(0)
