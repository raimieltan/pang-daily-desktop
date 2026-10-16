extends SceneTree
## Scripted visual checks (needs a window, not --headless):
## `godot --path . -s res://tools/screenshot.gd -- <scene> <out_dir> <scenario>`
## Scenarios: day, brake, drift, scrape, night, overview, spectate (autopilot VS, every cinematic
## shot, then the replay at full and quarter speed). Each scripts the pedals, saves PNGs at
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
	# Standing shot (pair with PANG_DIST) to check roadside props by day. PANG_EYE="d,lat,h,d2,lat2,h2"
	# frames it from a fixed eye at road distance d, lateral lat (right +), height h, aimed at d2.
	# PANG_FREE=1 starts in free drive (the roadside traffic only rides there).
	"props": [[1.5, 0, 0, 0, 0, "props_day"]],
	# A burst radiator hose (steam from the hood) while rolling, then parked; and an exhaust pop on
	# lifting off at high revs (the flame lasts ~0.1 s, so a burst of shots just after the lift).
	"steam": [[2.0, 0, 0, 0, 0, ""], [5.0, 0.7, 0, 0, 0, ""], [6.2, 0.4, 0, 0, 0, "steam_rolling"], [9.0, 0, 1, 0, 0, "steam_stopped"]],
	"pop": [[2.0, 0, 0, 0, 0, ""], [7.5, 1, 0, 0, 0, ""], [7.58, 0, 0, 0, 0, "pop_a"], [7.64, 0, 0, 0, 0, "pop_b"],
		[7.7, 0, 0, 0, 0, "pop_c"], [7.76, 0, 0, 0, 0, "pop_d"], [8.2, 0, 0, 0, 0, "pop_puffs"]],
	# Menus: the title on launch; the pause menu over a run.
	"title": [[1.5, 0, 0, 0, 0, "title"]],
	"pause": [[2.0, 0, 0, 0, 0, ""], [6.0, 0.85, 0, 0, 0, ""], [6.3, 0, 0, 0, 0, "pause"]],
	# Garage: opened from FREE DRIVE, focus moves to the Silak (or PANG_CAR), it is picked and driven.
	"garage": [[1.0, 0, 0, 0, 0, ""], [2.5, 0, 0, 0, 0, "garage"], [3.0, 0, 0, 0, 0, ""], [4.5, 0, 0, 0, 0, "garage_silak"],
		[5.0, 0, 0, 0, 0, ""], [12.0, 0.85, 0, 0, 0, "garage_drive"]],
	# Settings page from the title (music slider lit), and the VS garage with its opponents gauge.
	"settings": [[1.0, 0, 0, 0, 0, ""], [2.0, 0, 0, 0, 0, ""], [3.0, 0, 0, 0, 0, "settings"],
		[3.2, 0, 0, 0, 0, ""], [4.5, 0, 0, 0, 0, "garage_vs"]],
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
	_steps = SCENARIOS[_scenario] if SCENARIOS.has(_scenario) else []
	if _scenario == "spectate":
		_steps = [[0.5, 0, 0, 0, 0, ""], [14.0, 0, 0, 0, 0, "spec_live"]]
		for i in CinematicDirector.Shot.size():
			_steps.append([15.0 + i * 1.6, 0, 0, 0, 0, ""])
			_steps.append([16.2 + i * 1.6, 0, 0, 0, 0, "cine_%d_%s" % [i, CinematicDirector.SHOT_NAMES[i].replace(" ", "_").to_lower()]])
		var t0 := 16.0 + CinematicDirector.Shot.size() * 1.6
		_steps.append_array([[t0, 0, 0, 0, 0, ""], [t0 + 1.5, 0, 0, 0, 0, "replay_hud"], [t0 + 1.6, 0, 0, 0, 0, ""],
			[t0 + 3.0, 0, 0, 0, 0, "replay_slow"], [t0 + 3.2, 0, 0, 0, 0, ""], [t0 + 4.5, 0, 0, 0, 0, "replay_clean"]])
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
		if OS.has_environment("PANG_EYE"):
			_eye_camera(session)
		if OS.has_environment("PANG_FREE"):
			_scene.time_attack.free_drive()
		if OS.has_environment("PANG_MANGA_OFF"):
			session.camera.manga.enabled = false
		if OS.has_environment("PANG_SCALE"):
			root.scaling_3d_scale = float(OS.get_environment("PANG_SCALE"))
		session.camera._fit_render_scale()
		if OS.has_environment("PANG_SCALE"):
			root.scaling_3d_scale = float(OS.get_environment("PANG_SCALE"))
		print("3d scale ", root.scaling_3d_scale, " window ", root.size)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if _scenario == "spectate":
		if _scene.vs_battle._in_intro:
			_scene.intro.skip()
	elif session.car.input_source != _scripted:
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
		if _scenario == "spectate":
			var cine := session.camera.director
			var shots := CinematicDirector.Shot.size()
			if _step == 0:
				_scene.menu._start_spectate()
			elif _step >= 2 and _step < 2 + shots * 2 and _step % 2 == 0:
				cine._new_shot(cine.focus_car())
				cine.shot = (_step - 2) / 2
				if cine.shot == CinematicDirector.Shot.TRACKSIDE or cine.shot == CinematicDirector.Shot.FLYBY:
					cine._find_anchor(cine.focus_car())
				cine._shot_time = 99.0
			elif _step == 2 + shots * 2:
				session.replay.start()
			elif _step == 4 + shots * 2:
				session.replay.speed_index = 1
				Engine.time_scale = 0.25
			elif _step == 6 + shots * 2:
				session.set_clean_feed(true)
		if _scenario == "pause" and _step == 1:
			_scene.menu.open_pause()
		if _scenario == "settings":
			var menu: GameMenu = _scene.menu
			match _step:
				0: menu._open_settings(menu.open_title)
				1: menu._value_buttons.filter(func(p): return p[0].text == "MUSIC")[0][0].grab_focus()
				3:
					menu._open_garage("VS BATTLE", menu._start_vs)
					menu._opponents_button.grab_focus.call_deferred()
		if _scenario == "garage":
			var menu: GameMenu = _scene.menu
			match _step:
				0: menu._open_garage("FREE DRIVE", menu._start_free_drive)
				2: menu._car_buttons[OS.get_environment("PANG_CAR") if OS.has_environment("PANG_CAR") else "silak_box"].grab_focus()
				4: menu._car_buttons[OS.get_environment("PANG_CAR") if OS.has_environment("PANG_CAR") else "silak_box"].pressed.emit()
		if step[5] != "":
			if _scenario == "overview":
				_overview_camera(session)
			_shot(step[5])
		if _scenario == "cams" and _step >= 1:
			session.camera.mode = (_step % ChaseCamera.Mode.size()) as ChaseCamera.Mode
		if _scenario == "steam" and _step == 1:
			session.fx.burst_steam(10.0)
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


func _eye_camera(session: DriveSession) -> void:
	var v := OS.get_environment("PANG_EYE").split_floats(",")
	var track: TrackData = _scene.track
	var at := func(d: float, lateral: float, h: float) -> Vector3:
		var i := track.index_at(d)
		return track.points[i] + track.rights[i] * lateral + Vector3.UP * h
	var cam := Camera3D.new()
	_scene.add_child(cam)
	cam.global_position = at.call(v[0], v[1], v[2])
	cam.look_at(at.call(v[3], v[4], v[5]))
	cam.compositor = session.camera.compositor
	cam.current = true


func _shot(name: String) -> void:
	# Overview: let the new camera render once before capturing.
	if _scenario == "overview":
		RenderingServer.force_draw()
	if OS.has_environment("PANG_NO_PAGE"):
		_scene.session.camera.manga.enabled = false
	if _scenario == "pop":
		print("  pipe (car space, +x right) ", _scene.session.fx._pipe)
		print("  rpm %.0f throttle %.2f flame %s" % [_scene.session.car.model.mechanics.engine_rpm,
			_scene.session.car.model.state.throttle, _scene.session.fx._flame.visible])
	var life: Node = _scene.get_node_or_null("RoadsideLife")
	if life:
		for n in life.get_children():
			print("  %s at %.1f m  %s" % [n.name, n.get("distance") if n.get("distance") != null else n.get("_d"), n.global_position])
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("saved ", path)
