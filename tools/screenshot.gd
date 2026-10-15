extends SceneTree
## Scripted visual checks (needs a window, not --headless):
## `godot --path . -s res://tools/screenshot.gd -- <scene> <out_dir> <scenario>`
## Scenarios: day, brake, drift, scrape, night, overview. Each scripts the pedals, saves PNGs at
## the interesting moments and prints frame-time stats (vsync off) for the driving part.

const SCENARIOS := {
	# [until_seconds, throttle, brake, steer, handbrake, shot name or ""]
	"day": [[2.0, 0, 0, 0, 0, ""], [9.0, 0.85, 0, 0, 0, "day_drive"]],
	"brake": [[2.0, 0, 0, 0, 0, ""], [9.0, 1, 0, 0, 0, ""], [9.6, 0, 1, 0, 0, "brake"]],
	"drift": [[2.0, 0, 0, 0, 0, ""], [9.0, 1, 0, 0, 0, ""], [10.3, 0.6, 0, -1, 1, "drift_mid"], [11.2, 0.6, 0, 0.4, 0, "drift_after"]],
	# Into the guardrail on the left of the start straight.
	"scrape": [[2.0, 0, 0, 0, 0, ""], [8.0, 1, 0, 0, 0, ""], [9.0, 1, 0, -0.55, 0, ""], [9.3, 1, 0, -0.35, 0, "scrape_a"], [9.6, 1, 0, -0.3, 0, "scrape_b"], [10.0, 1, 0, -0.3, 0, "scrape_c"]],
	"night": [[1.0, 0, 0, 0, 0, "night_spawn"], [8.0, 0.85, 0, 0, 0, "night_drive"], [8.6, 0, 1, 0, 0, "night_brake"]],
	"overview": [[2.0, 0, 0, 0, 0, ""], [9.0, 0.85, 0, 0, 0, "overview"]],
}

var _scene
var _out := "user://shots"
var _scenario := "day"
var _steps: Array = []
var _t := 0.0
var _step := 0
var _frames := 0
var _frame_time_sum := 0.0
var _worst := 0.0
var _input := VehicleTypes.DriverInput.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://scenes/touge.tscn"
	if args.size() > 1: _out = args[1]
	if args.size() > 2: _scenario = args[2]
	_steps = SCENARIOS[_scenario]
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280, 720)
	_scene = load(scene_path).instantiate()
	root.add_child(_scene)
	if _scenario == "night":
		MangaArt.set_night(true)


func _scripted() -> VehicleTypes.DriverInput:
	return _input


func _process(delta: float) -> bool:
	var session: DriveSession = _scene.session
	if session.car.input_source != _scripted:
		session.car.input_source = _scripted
	_t += delta
	if _t > 2.0:
		_frames += 1
		_frame_time_sum += delta
		_worst = maxf(_worst, delta)
	var step: Array = _steps[_step]
	_input = VehicleTypes.DriverInput.make(step[1], step[2], step[3], step[4], "keyboard")
	if _t >= step[0]:
		if step[5] != "":
			if _scenario == "overview":
				_overview_camera(session)
			_shot(step[5])
		_step += 1
		if _step >= _steps.size():
			var avg := _frame_time_sum / maxf(1, _frames)
			print("perf %s: %d frames, avg %.2f ms (%.0f fps), worst %.2f ms, physics %.2f ms, objects drawn %d, primitives %d" % [
				_scenario, _frames, avg * 1000.0, 1.0 / avg, _worst * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
			return true
	return false


func _overview_camera(session: DriveSession) -> void:
	var cam := Camera3D.new()
	_scene.add_child(cam)
	var p := session.car.global_position
	cam.global_position = p + Vector3(120, 160, 260)
	cam.look_at(p + Vector3(0, -40, -160))
	cam.far = 4000
	cam.add_child(MangaArt.post_quad())
	cam.current = true


func _shot(name: String) -> void:
	# Overview: let the new camera render once before capturing.
	if _scenario == "overview":
		RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("saved ", path)
