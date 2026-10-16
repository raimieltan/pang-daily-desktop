extends SceneTree
## Trailer capture driver. The game never loads this: `trailer/capture.sh <shot>` writes a
## temporary override.cfg (frame size, MJPEG quality) and runs
##   godot --path . --write-movie trailer/out/<shot>.avi --fixed-fps 60 -s res://trailer/capture.gd -- --trailer-shot=<shot>
## Each shot loads the touge map, stages a moment (a VS battle from the back of the grid, a
## powerslide run, the race intro, the garage…), drives the camera from a schedule and quits.
## Next to the AVI it writes <shot>.events.json: overtakes, slides and camera cuts with times.
##
## Flags (after `--`):
##   --trailer-shot=<name>   which shot (see SHOTS)
##   --out=<dir>             where events/stills go (default trailer/out)
##   --probe                 no camera work, just the sim + events (pair with --headless)
##   --stills=<t,t,…>        save clean PNGs of the frame at these times (no movie needed)
##   --still-size=<WxH>      render those stills offscreen at this size (macOS caps the window at
##                           the display size, so 4K stills can't come from the window itself)

const DriftPilot := preload("res://trailer/drift_pilot.gd")
const EventLog := preload("res://trailer/event_log.gd")
const D := CinematicDirector.Shot
const DIRECTOR_SHOTS := { "trackside": D.TRACKSIDE, "flyby": D.FLYBY, "chase_low": D.CHASE_LOW, "heli": D.HELI,
	"drone": D.DRONE, "wheel": D.WHEEL, "nose": D.NOSE, "orbit": D.ORBIT, "lead": D.LEAD }
const GAME_SHOTS := { "chase": ChaseCamera.Mode.CHASE, "far": ChaseCamera.Mode.FAR,
	"hood": ChaseCamera.Mode.HOOD, "bumper": ChaseCamera.Mode.BUMPER }

## Every shot: its staging function and how long it runs (s).
const SHOTS := {
	"battle": { "stage": "_battle", "seconds": 62.0 },
	"drift": { "stage": "_drift", "seconds": 48.0 },
	"intro": { "stage": "_intro", "seconds": 16.5 },
	"daynight": { "stage": "_daynight", "seconds": 12.0 },
	"cars": { "stage": "_cars", "seconds": 20.0 },
	"garage": { "stage": "_garage", "seconds": 9.0 },
}

var scene
var session: DriveSession
var ev := EventLog.new()
var t := 0.0
var shot := ""
var out_dir := "res://trailer/out"
var probe := false
var stills: Array[float] = []
var still_size := Vector2i.ZERO
var _still_vp: SubViewport
var _still_cam: Camera3D
## --car=<roster id> and --pilot=<field>:<value>,… override a shot's car and drift pilot.
var car_override := ""
var pilot_overrides := {}
var _length := 10.0
var _done := false
# Camera rig: the shot in use, the car it frames and which side it stands on.
var _cam := "chase"
var _cam_car: CarBody
var _cam_side := 1.0
var _cam_snap := false
var _side_pos := Vector3.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trailer-shot="): shot = a.get_slice("=", 1)
		elif a.begins_with("--out="): out_dir = a.get_slice("=", 1)
		elif a == "--probe": probe = true
		elif a.begins_with("--car="): car_override = a.get_slice("=", 1)
		elif a.begins_with("--pilot="):
			for kv in a.get_slice("=", 1).split(","):
				pilot_overrides[kv.get_slice(":", 0)] = float(kv.get_slice(":", 1))
		elif a.begins_with("--stills="):
			for s in a.get_slice("=", 1).split(","):
				stills.append(float(s))
		elif a.begins_with("--still-size="):
			var wh := a.get_slice("=", 1).split("x")
			still_size = Vector2i(int(wh[0]), int(wh[1]))
	if not SHOTS.has(shot):
		push_error("unknown --trailer-shot=%s (have %s)" % [shot, ", ".join(SHOTS.keys())])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_length = SHOTS[shot]["seconds"]
	GameMenu.skip_title = shot != "garage"
	scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(scene)


func _process(delta: float) -> bool:
	if scene == null:
		return true
	if session == null:
		# The map builds its session in _ready, after _initialize.
		session = scene.session
		ev.track = scene.track
		call(SHOTS[shot]["stage"])
		# Full-res 3D for footage (the game drops to ~0.6 above 1200 px tall), music off: the
		# trailer lays its own track; engine, tires and impacts stay in the AVI's audio.
		root.scaling_3d_scale = 1.0
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
		session.set_clean_feed(true)
	t += delta
	ev.step(t)
	if not probe:
		_drive_camera(delta)
	while not stills.is_empty() and t >= stills[0]:
		_still(stills.pop_front())
	if still_size != Vector2i.ZERO and not stills.is_empty():
		_sync_still_view()
	if t >= _length and not _done:
		_done = true
		ev.save(ProjectSettings.globalize_path(out_dir.path_join(shot + ".events.json")),
			{ "shot": shot, "seconds": _length, "fps": Engine.get_frames_per_second(),
			"size": [root.size.x, root.size.y] })
		return true
	return false


func _until(seconds: float) -> void:
	while t < seconds:
		await process_frame


func _physics_wait(n: int) -> void:
	for i in n:
		await physics_frame


## Point the trailer camera: a game view ("chase", "far", "hood", "bumper"), a director rig
## ("trackside", "flyby", "chase_low", "heli", "drone", "wheel", "nose", "orbit", "lead") or
## "side" (tracking alongside, good for slides in portrait).
func cam(name: String, car: CarBody = null, side := 1.0) -> void:
	_cam = name
	_cam_car = car if car else session.car
	_cam_side = side
	_cam_snap = true
	var names: Array = ev.names
	var who: String = names[ev.cars.find(_cam_car)] if ev.cars.has(_cam_car) else "YOU"
	ev.cut(t, name, who)


func _drive_camera(delta: float) -> void:
	var c := session.camera
	var car := _cam_car if is_instance_valid(_cam_car) else session.car
	if GAME_SHOTS.has(_cam):
		if c.target != car or c.mode != GAME_SHOTS[_cam]:
			c.target = car
			c.mode = GAME_SHOTS[_cam]
		return
	# Everything else is placed here; with no target the ChaseCamera leaves the transform alone.
	if c.mode == ChaseCamera.Mode.CINEMATIC:
		c.mode = ChaseCamera.Mode.CHASE
	c.target = null
	var dir := c.director
	dir._space = c.get_world_3d().direct_space_state
	var speed := car.linear_velocity.length()
	if DIRECTOR_SHOTS.has(_cam):
		if _cam_snap:
			dir.shot = DIRECTOR_SHOTS[_cam]
			dir._side = _cam_side
			dir._angle = 0.6 if _cam_side > 0.0 else 3.7
			if dir.shot == D.TRACKSIDE or dir.shot == D.FLYBY:
				dir._find_anchor(car)
		dir._place(c, car, delta, _cam_snap)
		c._effects(delta, speed if dir.speed_lines() else 0.0)
	elif _cam == "side":
		var xf := car.get_global_transform_interpolated()
		var p := xf.origin + Vector3.UP * 0.5
		var v := car.linear_velocity
		v.y = 0.0
		var f := v.normalized() if v.length() > 3.0 else -xf.basis.z
		var r := f.cross(Vector3.UP).normalized()
		var want := p + r * 7.0 * _cam_side + Vector3.UP * 1.6 - f * 1.5
		_side_pos = want if _cam_snap else _side_pos.lerp(want, 1.0 - exp(-6.0 * delta))
		c.global_position = _side_pos
		c.fov = 52.0
		c.look_at(p + f * 1.5)
		c._effects(delta, speed)
	_cam_snap = false


func _still(at: float) -> void:
	# The offscreen view drew last frame with last frame's camera: the same moment, one frame back.
	var img := (_still_vp if _still_vp else root).get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir.path_join("%s_%05.2f_%dx%d.png" % [shot, at, img.get_width(), img.get_height()]))
	img.save_png(path)
	print("still ", path)



## An offscreen viewport sharing the world, with a camera that mirrors the live one (including
## its manga compositor, which scales with resolution), so stills can be larger than the window.
func _sync_still_view() -> void:
	var live := root.get_camera_3d()
	if live == null:
		return
	if _still_vp == null:
		_still_vp = SubViewport.new()
		_still_vp.size = still_size
		_still_vp.world_3d = root.world_3d
		_still_vp.msaa_3d = root.msaa_3d
		_still_vp.screen_space_aa = root.screen_space_aa
		_still_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_still_cam = Camera3D.new()
		_still_vp.add_child(_still_cam)
		root.add_child(_still_vp)
	_still_cam.global_transform = live.global_transform
	_still_cam.fov = live.fov
	_still_cam.near = live.near
	_still_cam.far = live.far
	_still_cam.keep_aspect = live.keep_aspect
	_still_cam.environment = live.environment
	_still_cam.attributes = live.attributes
	_still_cam.compositor = live.compositor
	_still_cam.current = true


## Hand the player's car to the autopilot at `skill`, optionally with the drift pilot on top.
func _autopilot(skill: float, drift := false) -> void:
	session.set_autopilot(true)
	session.autopilot.skill = skill
	if drift:
		var pilot := DriftPilot.new(session.car, session.autopilot, scene.track)
		for k in pilot_overrides:
			pilot.set(k, pilot_overrides[k])
		var before: Callable = session.input_filter
		session.input_filter = func(i: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
			i = pilot.filter(i)
			return before.call(i) if before.is_valid() else i


func _free_drive(car_id: String, night: bool, at_m: float, drift_tune := false) -> void:
	MangaArt.set_night(night)
	scene.menu._start_free_drive()
	session.set_car(car_id)
	if drift_tune:
		session.car.set_preset(session.car_spec["preset"] + "_drift")
	var pose: Dictionary = scene.track.pose_at(at_m)
	session.car.place(pose["position"], pose["heading"])
	ev.watch([session.car], ["YOU"])
	await _physics_wait(2)


# ---------------------------------------------------------------- shots

## Night VS battle against all five rivals, the player gridded last and pushing hard, so the
## field gets carved through. Camera cuts are timed off a probe run of the same race.
func _battle() -> void:
	MangaArt.set_night(true)
	scene.time_attack.free_drive()
	var vs: VsBattle = scene.vs_battle
	vs.opponents = 5
	vs.start()
	# Swap the player to the back of the grid with the last rival.
	var tr: TrackData = scene.track
	var back := tr.pose_at(tr.start_distance - 6.0 - 2 * VsBattle.GRID_ROW, VsBattle.GRID_LANE)
	var mine := tr.pose_at(tr.start_distance - 6.0 - VsBattle.GRID_ROW, -VsBattle.GRID_LANE)
	session.car.place(back["position"], back["heading"])
	vs.rivals[4].place(mine["position"], mine["heading"])
	var cars: Array = [session.car]
	cars.append_array(vs.rivals)
	ev.watch(cars, ["YOU"] + VsBattle.RIVALS.map(func(r): return r["name"]))
	while vs.run == null:
		if vs._in_intro:
			scene.intro.skip()
		await process_frame
	await _physics_wait(2)
	_autopilot(1.06)
	# Rivals a touch off the pace so the player carves through the field.
	for d in vs.drivers:
		d.skill *= RIVAL_PACE
	ev.mark(t, "countdown")
	for step in BATTLE_CAMS:
		await _until(step[0])
		var who: CarBody = session.car if step.size() < 3 or step[2] == null else vs.rivals[step[2]]
		cam(step[1], who, step[3] if step.size() > 3 else 1.0)


const RIVAL_PACE := 0.93

## [time, shot, rival index or omitted for the player, side]
## Passes at 6.6, 7.5, 11.7, 21.4 and 29.2 s are framed from above or behind: in the pack,
## low and nose rigs end up with a rival filling (or inside) the lens.
const BATTLE_CAMS := [
	[0.0, "chase"], [5.2, "drone"], [8.6, "chase"], [10.4, "far"], [13.2, "trackside", 2],
	[16.6, "side", 2, -1.0], [19.6, "drone", null, -1.0], [23.0, "heli"], [25.6, "lead"], [27.8, "chase"],
	[30.2, "side", 0, 1.0], [32.6, "drone"], [35.6, "flyby"], [39.0, "heli"], [42.5, "chase_low", null, -1.0],
	[46.0, "orbit"], [49.8, "drone", 3], [53.5, "lead", 3, -1.0], [56.2, "side", 3], [59.0, "far"],
]


## The hero car on its drift tune at night, flicking into every corner.
func _drift() -> void:
	await _free_drive(car_override if car_override else DRIFT_CAR, true, scene.track.start_distance + 5.0, true)
	_autopilot(1.0, true)
	for step in DRIFT_CAMS:
		await _until(step[0])
		cam(step[1], null, step[2] if step.size() > 2 else 1.0)


const DRIFT_CAR := "silak_box"

## Cut so every slide from the probe run (8.5, 12, 16, 31.7, 36.4, 40.7 s) lands on a good angle.
const DRIFT_CAMS := [
	[0.0, "chase"], [7.4, "side"], [10.7, "chase_low"], [14.9, "wheel"], [17.5, "drone"], [22.0, "lead", -1.0],
	[26.0, "heli"], [30.6, "side", -1.0], [34.0, "orbit"], [35.6, "chase_low", -1.0], [39.4, "side"], [43.5, "chase"],
]


## The VS battle intro as the game plays it: crane over the grid, the rival cards, the countdown.
func _intro() -> void:
	MangaArt.set_night(true)
	scene.time_attack.free_drive()
	scene.vs_battle.opponents = 3
	session.set_clean_feed(false)
	scene.vs_battle.start()
	var cars: Array = [session.car]
	cars.append_array(scene.vs_battle.rivals)
	ev.watch(cars, ["YOU", "JUNJUN", "ATE LIZA", "KAPITAN"])
	await _physics_wait(2)
	_autopilot(1.0)
	_cam = "chase"
	await scene.intro.finished
	ev.mark(t, "intro_end")


## Same corner, day flipping to night while the car drives through it.
func _daynight() -> void:
	await _free_drive("dalagan_gsr", false, scene.track.start_distance + 120.0)
	_autopilot(0.95)
	cam("lead", null, -1.0)
	await _until(4.0)
	session.day_night.toggle()
	ev.mark(t, "toggle_night")
	await _until(8.0)
	cam("orbit")


## One clip of each garage car on the road, night.
func _cars() -> void:
	var ids := ["dalagan_gsr", "silak_box", "eg_hatch", "civic_fd"]
	var shots := ["nose", "lead", "nose", "lead"]
	for k in ids.size():
		await _free_drive(ids[k], true, scene.track.start_distance + 200.0 + k * 260.0)
		_autopilot(1.0)
		ev.mark(t, ids[k])
		cam(shots[k], null, -1.0 if k % 2 else 1.0)
		await _until((k + 1) * 5.0)
		session.set_autopilot(false)


## Title, then the garage cycling through every car (captured landscape; the edit zooms in).
func _garage() -> void:
	var menu: GameMenu = scene.menu
	await _until(1.0)
	menu._open_garage("FREE DRIVE", menu._start_free_drive)
	var ids := ["dalagan_gsr", "silak_box", "eg_hatch", "civic_fd"]
	for k in ids.size():
		await _until(2.0 + k * 1.6)
		menu._car_buttons[ids[k]].grab_focus()
		ev.mark(t, ids[k])
