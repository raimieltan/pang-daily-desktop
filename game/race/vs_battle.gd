class_name VsBattle
extends Node
## A downhill battle: the player against AI rivals from a two-wide grid. Intro, countdown with
## everyone on the brakes, live positions, the finishing order, and a result page.
## Reset (R) puts the player back at the last checkpoint; Enter restarts.

signal finished(place: int)

const GRID_ROW := 7.5
const GRID_LANE := 1.7
## Each rival: who, which body, what tune, and how hard they push.
const RIVALS := [
	{ "name": "JUNJUN", "car": "EG HATCH", "model": "res://assets/vehicles/civic_eg/civic_eg_modular.glb",
		"preset": "fwd_sport_hatch", "paint": Color(0.93, 0.93, 0.9), "skill": 1.0 },
	{ "name": "ATE LIZA", "car": "CIVIC FD", "model": "res://assets/vehicles/civic-fd/civic_fd_2007_modular.glb",
		"preset": "fwd_sport_hatch", "paint": Color(0.85, 0.1, 0.12), "skill": 0.97 },
	{ "name": "KAPITAN", "car": "SILAK BOX", "model": "res://assets/vehicles/lancer/lancer_box_1983_modular.glb",
		"preset": "rwd_box_turbo", "paint": Color(0.12, 0.3, 0.75), "skill": 0.9 },
]

var track: TrackData
var session: DriveSession
var hud: RaceHud
var intro: RaceIntro
var music: MusicPlayer
var run: TimeAttackRun
var active := false
var rivals: Array[CarBody] = []
var drivers: Array[AiDriver] = []
var _finish_times := {}   # driver index -> time
var _player_place := 0
## Race time that keeps running after the player finishes, for rivals still on the road.
var _clock := 0.0
var _index_hint := 0
var _in_intro := false


func _ready() -> void:
	hud = RaceHud.new()
	hud.visible = false
	add_child(hud)


func start() -> void:
	_clear_rivals()
	active = true
	session.input_filter = _filter_input
	session.reset_pose = _reset_pose
	run = null
	_finish_times.clear()
	_player_place = 0
	_clock = 0.0
	var grid := _grid()
	var pose: Dictionary = grid[0]
	session.car.place(pose["position"], pose["heading"])
	session.camera.snap.call_deferred()
	_index_hint = track.index_at(track.start_distance)
	for k in RIVALS.size():
		_spawn_rival(RIVALS[k], grid[k + 1], k)
	hud.visible = true
	hud.show_versus(RIVALS.map(func(r): return r["name"]))
	_in_intro = true
	if music:
		music.play_track(&"race")
	await get_tree().physics_frame
	await get_tree().physics_frame
	if session.minimap:
		session.minimap.rivals.assign(rivals)
	if intro:
		var cast: Array = [{ "node": session.car, "name": "YOU", "car": session.car_spec["name"] }]
		for k in rivals.size():
			cast.append({ "node": rivals[k], "name": RIVALS[k]["name"], "car": RIVALS[k]["car"] })
		hud.visible = false
		intro.play(track, cast, "VS BATTLE", "PASS 1  ·  DOWNHILL")
		await intro.finished
		if not active:
			return
	hud.visible = true
	_in_intro = false
	run = TimeAttackRun.new(track.start_distance, track.finish_distance)
	session.camera.snap.call_deferred()


func stop() -> void:
	active = false
	run = null
	hud.visible = false
	if intro:
		intro.skip()
	_clear_rivals()
	if session.minimap:
		session.minimap.rivals.clear()


## Grid behind the start line: two wide, the player on the second row left.
func _grid() -> Array:
	var slots := []
	for row in 2:
		for side in [-1.0, 1.0]:
			slots.append(track.pose_at(track.start_distance - 6.0 - row * GRID_ROW, side * GRID_LANE))
	# Player second row, left; rivals fill the rest front to back.
	return [slots[2], slots[0], slots[1], slots[3]]


func _spawn_rival(spec: Dictionary, pose: Dictionary, k: int) -> void:
	var car := CarBody.new()
	car.name = "Rival_%s" % spec["name"].replace(" ", "_")
	car.preset = spec["preset"]
	car.tire_product = "street"
	var driver := AiDriver.new(car, track, spec["skill"], -GRID_LANE if k % 2 == 0 else GRID_LANE)
	car.input_source = driver.input
	add_child(car)
	car.global_position = pose["position"]
	car.rotation.y = pose["heading"]
	var visual := CarVisual.new()
	visual.model_scene = load(spec["model"])
	visual.paint_color = spec["paint"]
	visual.car = car
	car.add_child(visual)
	car.place(pose["position"], pose["heading"])
	rivals.append(car)
	drivers.append(driver)


## Out of the tree now, not at frame end: a queued car would still step physics once more and
## call its driver, which is released with `drivers`.
func _clear_rivals() -> void:
	for car in rivals:
		car.input_source = func() -> VehicleTypes.DriverInput: return VehicleTypes.DriverInput.new()
		remove_child(car)
		car.queue_free()
	rivals.clear()
	drivers.clear()


func _filter_input(input: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
	if run == null or run.phase == TimeAttackRun.Phase.COUNTDOWN:
		input.throttle = minf(input.throttle, 1.0)
		input.brake = 1.0
		input.handbrake = 0.0
	return input


func _reset_pose(_car: CarBody) -> Dictionary:
	if run == null or run.phase == TimeAttackRun.Phase.FINISHED:
		return track.pose_at(track.distance_at(session.car.global_position, _index_hint))
	var d := run.respawn_distance()
	run.respawned(d)
	_index_hint = track.index_at(d)
	return track.pose_at(d)


func _unhandled_input(event: InputEvent) -> void:
	if active and not _in_intro and event.is_action_pressed("restart_run"):
		start()


func _physics_process(delta: float) -> void:
	if not active or run == null:
		return
	_index_hint = track.nearest_index(session.car.global_position, _index_hint)
	var events := run.update(delta, _index_hint * track.spacing)
	var racing := run.phase != TimeAttackRun.Phase.COUNTDOWN
	if racing:
		_clock += delta
	for k in drivers.size():
		var d := drivers[k]
		d.racing = racing and not _finish_times.has(k)
		d.cooldown = _finish_times.has(k)
		d.rival_distance = run.progress
		if racing and not _finish_times.has(k) and d.distance >= track.finish_distance:
			_finish_times[k] = _clock
			if _player_place > 0:
				hud.versus_result(_player_place, run.time, _standings_text())
	for e in events:
		match e:
			"go":
				hud.go()
			"finish":
				_player_place = 1 + _finish_times.size()
				hud.versus_result(_player_place, run.time, _standings_text())
				finished.emit(_player_place)


func _process(_delta: float) -> void:
	if not active or run == null:
		return
	hud.update_run(run)
	if run.phase == TimeAttackRun.Phase.RUNNING:
		hud.set_place(_live_place(), rivals.size() + 1)


func _live_place() -> int:
	var place := 1
	for k in drivers.size():
		if _finish_times.has(k) or drivers[k].distance > run.progress:
			place += 1
	return place


func _standings_text() -> String:
	var rows := []
	for k in drivers.size():
		var t: float = _finish_times.get(k, -1.0)
		rows.append([t if t >= 0.0 else INF, RIVALS[k]["name"], TimeAttackRun.format_time(t)])
	if _player_place > 0:
		rows.append([run.time, "YOU", TimeAttackRun.format_time(run.time)])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	var lines := []
	for i in rows.size():
		lines.append("%d.  %-9s %s" % [i + 1, rows[i][1], rows[i][2]])
	return "\n".join(lines)


func player_place() -> int:
	return _player_place
