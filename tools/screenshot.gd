extends SceneTree
## Scripted visual checks (needs a window, not --headless):
## `godot --path . -s res://tools/screenshot.gd -- <scene> <out_dir> <scenario>`
## Scenarios: day, brake, drift, scrape, night, overview. Each scripts the pedals, saves PNGs at
## the interesting moments and prints frame-time stats (vsync off) for the driving part.

const SCENARIOS := {
	# [until_seconds, throttle, brake, steer, handbrake, shot name or ""]
	"night_default": [[2.0, 0, 0, 0, 0, ""], [9.0, 0.85, 0, 0, 0, "night_default"]],
	"day": [[2.0, 0, 0, 0, 0, ""], [9.0, 0.85, 0, 0, 0, "day_drive"]],
	"brake": [[2.0, 0, 0, 0, 0, ""], [9.0, 1, 0, 0, 0, ""], [9.6, 0, 1, 0, 0, "brake"]],
	"drift": [[2.0, 0, 0, 0, 0, ""], [9.0, 1, 0, 0, 0, ""], [10.3, 0.6, 0, -1, 1, "drift_mid"], [11.2, 0.6, 0, 0.4, 0, "drift_after"]],
	# Into the guardrail on the left of the start straight.
	"scrape": [[2.0, 0, 0, 0, 0, ""], [8.0, 1, 0, 0, 0, ""], [9.0, 1, 0, -0.55, 0, ""], [9.3, 1, 0, -0.35, 0, "scrape_a"], [9.6, 1, 0, -0.3, 0, "scrape_b"], [10.0, 1, 0, -0.3, 0, "scrape_c"]],
	"night": [[1.0, 0, 0, 0, 0, "night_spawn"], [8.0, 0.85, 0, 0, 0, "night_drive"], [8.6, 0, 1, 0, 0, "night_brake"]],
	# Flips the on-screen day/night switch after the first shot.
	"switch": [[2.5, 0, 0, 0, 0, "switch_day"], [2.8, 0, 0, 0, 0, "switch_mid"], [3.6, 0, 0, 0, 0, "switch_night"]],
	"overview": [[2.0, 0, 0, 0, 0, ""], [9.0, 0.85, 0, 0, 0, "overview"]],
	# Standing shot (pair with PANG_DIST) to check roadside props by day.
	"props": [[1.5, 0, 0, 0, 0, "props_day"]],
	# Menus: the title on launch; the pause menu over a run.
	"title": [[1.5, 0, 0, 0, 0, "title"]],
	"pause": [[2.0, 0, 0, 0, 0, ""], [6.0, 0.85, 0, 0, 0, ""], [6.3, 0, 0, 0, 0, "pause"]],
	# Garage: opened from FREE DRIVE, focus moves to the Silak, it is picked and driven.
	"garage": [[1.0, 0, 0, 0, 0, ""], [2.5, 0, 0, 0, 0, "garage"], [3.0, 0, 0, 0, 0, ""], [4.5, 0, 0, 0, 0, "garage_silak"],
		[5.0, 0, 0, 0, 0, ""], [12.0, 0.85, 0, 0, 0, "garage_drive"]],
	# Camera views, one per shot after a short run (V cycles them in game).
	# VS battle: intro (crane, a rival card, the player card), then racing the rivals.
	"vs": [[0.3, 0, 0, 0, 0, ""], [1.8, 0, 0, 0, 0, "vs_intro_grid"], [4.4, 0, 0, 0, 0, "vs_intro_rival"], [10.2, 0, 0, 0, 0, "vs_intro_player"],
		[13.5, 0, 0, 0, 0, "vs_countdown"], [21.0, 0.9, 0, 0, 0, "vs_race"], [24.0, 0.9, 0, 0, 0, "vs_race_2"]],
	"cams": [[2.0, 0, 0, 0, 0, ""], [6.0, 0.85, 0, 0, 0, "cam_chase"], [6.3, 0.85, 0, 0, 0, "cam_far"], [6.6, 0.85, 0, 0, 0, "cam_hood"], [6.9, 0.85, 0, 0, 0, "cam_bumper"]],
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
var _gpu := 0.0
var _cpu := 0.0
var _proc := 0.0
var _input := VehicleTypes.DriverInput.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://scenes/touge.tscn"
	if args.size() > 1: _out = args[1]
	if args.size() > 2: _scenario = args[2]
	_steps = SCENARIOS[_scenario]
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Never steal keyboard focus from whoever is playing on this machine.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.size = Vector2i(1280, 720)
	if OS.has_environment("PANG_RES"):
		var r := OS.get_environment("PANG_RES").split("x")
		var size := Vector2i(int(r[0]), int(r[1]))
		DisplayServer.window_set_size(size)
		root.size = size
	GameMenu.skip_title = _scenario != "title"
	_scene = load(scene_path).instantiate()
	root.add_child(_scene)
	if _scenario == "night":
		MangaArt.set_night(true)
	elif _scenario != "switch":
		# Night is the default now; the day scenarios ask for day.
		MangaArt.set_night(false)


func _scripted() -> VehicleTypes.DriverInput:
	return _input


func _process(delta: float) -> bool:
	var session: DriveSession = _scene.session
	if _t == 0.0:
		if OS.has_environment("PANG_DIST"):
			var d := float(OS.get_environment("PANG_DIST"))
			var pose: Dictionary = _scene.track.pose_at(d)
			session.car.place(pose["position"], pose["heading"])
			session.camera.snap.call_deferred()
		if OS.has_environment("PANG_MANGA_OFF"):
			session.camera.manga.enabled = false
		if OS.has_environment("PANG_SCALE"):
			root.scaling_3d_scale = float(OS.get_environment("PANG_SCALE"))
		session.camera._fit_render_scale()
		if OS.has_environment("PANG_SCALE"):
			root.scaling_3d_scale = float(OS.get_environment("PANG_SCALE"))
		print("3d scale ", root.scaling_3d_scale, " window ", root.size)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if session.car.input_source != _scripted:
		session.car.input_source = _scripted
	_t += delta
	if _t > 2.0:
		_gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		_cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_frames += 1
		_frame_time_sum += delta
		_worst = maxf(_worst, delta)
	var step: Array = _steps[_step]
	_input = VehicleTypes.DriverInput.make(step[1], step[2], step[3], step[4], "keyboard")
	if _t >= step[0]:
		if _scenario == "vs" and _step == 0:
			_scene.time_attack.free_drive()
			_scene.vs_battle.start()
		if _scenario == "pause" and _step == 1:
			_scene.menu.open_pause()
		if _scenario == "garage":
			var menu: GameMenu = _scene.menu
			match _step:
				0: menu._open_garage("FREE DRIVE", menu._start_free_drive)
				2: menu._car_buttons["silak_box"].grab_focus()
				4: menu._car_buttons["silak_box"].pressed.emit()
		if step[5] != "":
			if _scenario == "overview":
				_overview_camera(session)
			_shot(step[5])
		if _scenario == "cams" and _step >= 1:
			session.camera.mode = (_step % ChaseCamera.Mode.size()) as ChaseCamera.Mode
		if _scenario == "switch" and _step == 0:
			session.day_night.toggle()
		_step += 1
		if _step >= _steps.size():
			var avg := _frame_time_sum / maxf(1, _frames)
			print("  gpu %.2f ms, render cpu %.2f ms, script process %.2f ms per frame" % [_gpu / _frames, _cpu / _frames, _proc / _frames])
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
	cam.compositor = _scene.session.camera.compositor
	cam.current = true


func _shot(name: String) -> void:
	# Overview: let the new camera render once before capturing.
	if _scenario == "overview":
		RenderingServer.force_draw()
	if OS.has_environment("PANG_NO_PAGE"):
		_scene.session.camera.manga.enabled = false
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("saved ", path)
