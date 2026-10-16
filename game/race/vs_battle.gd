class_name VsBattle
extends Node
## A downhill battle: the player against AI rivals from a two-wide grid. Intro, countdown with
## everyone on the brakes, live positions, the finishing order, and a result page.
## Reset (R) puts the player back at the last checkpoint; Enter restarts.
## With `sp_rival` set it is an SP battle instead: 1v1 side by side, and the SP gauges decide it
## (SpBattleRules) after a rolling run-up.

signal finished(place: int)

const GRID_ROW := 7.5
const GRID_LANE := 1.7
## SP battles: metres past the start line before the gauges arm, and the speed both cars are held
## to until then, so they reach the SP line together (a rolling start).
const SP_RUN_UP := 150.0
const SP_ROLL_KMH := 70.0
## Run-up pacing: the car ahead by more than this lifts, and brakes lightly past twice this (m);
## the car behind may run this much over the rolling speed to close up (km/h).
const SP_ROLL_GAP := 5.0
const SP_ROLL_CATCH_KMH := 15.0
## The rival's pace once the battle is decided, as a share of its skill.
const SP_CRUISE := 0.75
## Each rival: who, which body, what tune, and how hard they push.
const RIVALS := [
	{ "name": "JUNJUN", "car": "EG HATCH", "model": "res://assets/vehicles/civic_eg/civic_eg_modular.glb",
		"preset": "fwd_sport_hatch", "paint": Color(0.93, 0.93, 0.9), "skill": 1.0 },
	{ "name": "ATE LIZA", "car": "CIVIC FD2R", "model": "res://assets/vehicles/civic-fd/civic_fd_2007_modular.glb",
		"preset": "fwd_fd2r", "paint": Color(0.85, 0.1, 0.12), "skill": 0.97 },
	{ "name": "KAPITAN", "car": "SILAK BOX", "model": "res://assets/vehicles/lancer/lancer_box_1983_modular.glb",
		"preset": "rwd_box_turbo", "paint": Color(0.12, 0.3, 0.75), "skill": 0.9 },
	{ "name": "BUKO", "car": "DALAGAN GSR", "model": "res://assets/vehicles/dalagan_evo/dalagan_evo_modular.glb",
		"preset": "awd_gsr", "paint": Color(0.1, 0.42, 0.24), "skill": 0.93 },
	{ "name": "TISOY", "car": "EG HATCH", "model": "res://assets/vehicles/civic_eg/civic_eg_modular.glb",
		"preset": "fwd_sport_hatch", "paint": Color(0.09, 0.09, 0.1), "skill": 0.92 },
]

var track: TrackData
var session: DriveSession
var hud: RaceHud
var intro: RaceIntro
var music: MusicPlayer
## How many of RIVALS line up (1…RIVALS.size()); the menu sets it from GameSettings.
var opponents := 3
## SP battle against RIVALS[sp_rival]; -1 is the pack race. The menu sets it.
var sp_rival := -1
var sp: SpBattleRules
var run: TimeAttackRun
var active := false
var rivals: Array[CarBody] = []
var drivers: Array[AiDriver] = []
## The RIVALS entries on the road this race, in `rivals` order.
var field: Array = []
var _finish_times := {}   # driver index -> time
var _player_place := 0
## Race time that keeps running after the player finishes, for rivals still on the road.
var _clock := 0.0
var _index_hint := 0
var _in_intro := false
var _player_hit: Callable


func _ready() -> void:
	_player_hit = _on_wall_contact.bind(0)
	hud = RaceHud.new()
	hud.visible = false
	hud.add_to_group(&"play_hud")
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
	sp = null
	if sp_rival >= 0:
		field = [RIVALS[clampi(sp_rival, 0, RIVALS.size() - 1)]]
	else:
		field = RIVALS.slice(0, clampi(opponents, 1, RIVALS.size()))
	var grid := _grid(field.size())
	var pose: Dictionary = grid[0]
	session.car.place(pose["position"], pose["heading"])
	session.camera.snap.call_deferred()
	_index_hint = track.index_at(track.start_distance)
	for k in field.size():
		_spawn_rival(field[k], grid[k + 1], k)
	for d in drivers:
		d.others = field_cars()
	hud.visible = true
	if sp_rival >= 0:
		hud.show_sp(field[0]["name"])
	else:
		hud.show_versus(field.map(func(r): return r["name"]))
	_in_intro = true
	if music:
		music.play_track(&"intro" if intro else &"race")
	await get_tree().physics_frame
	await get_tree().physics_frame
	if session.minimap:
		session.minimap.rivals.assign(rivals)
	if intro:
		var cast: Array = [{ "node": session.car, "name": "YOU", "car": session.car_spec["name"] }]
		for k in rivals.size():
			cast.append({ "node": rivals[k], "name": field[k]["name"], "car": field[k]["car"] })
		hud.visible = false
		intro.play(track, cast, "SP BATTLE" if sp_rival >= 0 else "VS BATTLE", "PASS 1  ·  DOWNHILL")
		await intro.finished
		if not active:
			return
		if music:
			music.play_track(&"race")
	hud.visible = true
	_in_intro = false
	run = TimeAttackRun.new(track.start_distance, track.finish_distance)
	if sp_rival >= 0:
		sp = SpBattleRules.new(track.start_distance + SP_RUN_UP, track.finish_distance)
		if not session.car.wall_contact.is_connected(_player_hit):
			session.car.wall_contact.connect(_player_hit)
	session.camera.snap.call_deferred()
	var field_cars: Array[CarBody] = [session.car]
	field_cars.append_array(rivals)
	var field_names: Array[String] = ["YOU"]
	for k in rivals.size():
		field_names.append(field[k]["name"])
	session.replay.begin(field_cars, field_names)
	session.camera.director.set_cars(field_cars, field_names)


func stop() -> void:
	active = false
	run = null
	sp = null
	hud.visible = false
	if intro:
		intro.skip()
	_clear_rivals()
	if session.minimap:
		session.minimap.rivals.clear()
	session.camera.director.set_cars([session.car], ["YOU"])


## Grid behind the start line, two wide: [player, rival 1, rival 2, …]. One rival lines up
## beside the player; with more, the player starts second row left and rivals fill the rest.
func _grid(rival_count: int) -> Array:
	var slots := []
	for row in ceili((rival_count + 1) / 2.0):
		for side in [-1.0, 1.0]:
			slots.append(track.pose_at(track.start_distance - 6.0 - row * GRID_ROW, side * GRID_LANE))
	var mine := 2 if rival_count >= 2 else 0
	var out := [slots[mine]]
	for i in slots.size():
		if i != mine:
			out.append(slots[i])
	return out


func _spawn_rival(spec: Dictionary, pose: Dictionary, k: int) -> void:
	var car := CarBody.new()
	car.name = "Rival_%s" % spec["name"].replace(" ", "_")
	car.preset = spec["preset"]
	car.tire_product = "street"
	# The lane of its grid slot, so a rival beside the player keeps to its own side.
	var side := signf(track.lateral_offset(pose["position"], track.nearest_index(pose["position"])))
	var driver := AiDriver.new(car, track, spec["skill"], GRID_LANE * (side if side != 0.0 else 1.0))
	car.input_source = func() -> VehicleTypes.DriverInput: return _roll_cap(driver.input(), car, driver.distance - run.progress if run else 0.0)
	add_child(car)
	car.global_position = pose["position"]
	car.rotation.y = pose["heading"]
	var visual := CarVisual.new()
	visual.model_scene = load(spec["model"])
	visual.paint_color = spec["paint"]
	visual.car = car
	car.add_child(visual)
	car.place(pose["position"], pose["heading"])
	car.wall_contact.connect(_on_wall_contact.bind(k + 1))
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
	return _roll_cap(input, session.car, run.progress - drivers[0].distance if run and drivers.size() > 0 else 0.0)


## Before the SP line both cars are held to the rolling speed and to each other: `ahead` (m) is how
## far this car leads the other. Off throttle above the speed or in front; light brake further out.
func _roll_cap(input: VehicleTypes.DriverInput, car: CarBody, ahead: float) -> VehicleTypes.DriverInput:
	if sp == null or sp.phase != SpBattleRules.Phase.ROLLING:
		return input
	var kmh := car.speed_kmh()
	var cap := SP_ROLL_KMH + (SP_ROLL_CATCH_KMH if ahead < -SP_ROLL_GAP else 0.0)
	if kmh > cap or ahead > SP_ROLL_GAP:
		input.throttle = 0.0
	if (kmh > cap + 6.0 or ahead > 2.0 * SP_ROLL_GAP) and kmh > 40.0:
		input.brake = maxf(input.brake, 0.3)
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
	# Spectating: the player's autopilot sees the field too.
	if session.autopilot and session.autopilot.others.size() != rivals.size() + 1:
		session.autopilot.others = field_cars()
	var events := run.update(delta, _index_hint * track.spacing)
	var racing := run.phase != TimeAttackRun.Phase.COUNTDOWN
	if racing:
		_clock += delta
	for k in drivers.size():
		var d := drivers[k]
		d.racing = racing and not _finish_times.has(k)
		d.cooldown = _finish_times.has(k)
		d.rival_distance = -1.0 if sp and sp.phase == SpBattleRules.Phase.OVER else run.progress
		if racing and not _finish_times.has(k) and d.distance >= track.finish_distance:
			_finish_times[k] = _clock
			if _player_place > 0 and sp == null:
				hud.versus_result(_player_place, run.time, _standings_text())
	for e in events:
		match e:
			"go":
				hud.go()
			"finish":
				_player_place = 1 + _finish_times.size()
				if sp == null:
					hud.versus_result(_player_place, run.time, _standings_text())
					finished.emit(_player_place)
	if sp and racing and sp.phase != SpBattleRules.Phase.OVER:
		for e in sp.update(delta, run.progress, drivers[0].distance):
			match e:
				"armed":
					hud.sp_armed()
				"over":
					sp.time = run.time
					hud.sp_result(sp, field[0]["name"], sp.time)
					# Decided: the rival eases off and cruises on down (stopping here would park it
					# in the road ahead of a player who is still coming).
					drivers[0].skill *= SP_CRUISE
					finished.emit(1 if sp.winner == 0 else 2)


func _process(_delta: float) -> void:
	if not active or run == null:
		return
	# The clock stops when an SP battle is decided, though the road goes on.
	hud.update_run(run, sp.time if sp and sp.phase == SpBattleRules.Phase.OVER else -1.0)
	if sp:
		hud.update_sp(sp, maxf(run.progress, drivers[0].distance))
	elif run.phase == TimeAttackRun.Phase.RUNNING:
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
		rows.append([t if t >= 0.0 else INF, field[k]["name"], TimeAttackRun.format_time(t)])
	if _player_place > 0:
		rows.append([run.time, "YOU", TimeAttackRun.format_time(run.time)])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	var lines := []
	for i in rows.size():
		lines.append("%d.  %-9s %s" % [i + 1, rows[i][1], rows[i][2]])
	return "\n".join(lines)


## A wall or car hit on car `i` (0 the player, 1 the rival) costs SP in an SP battle.
func _on_wall_contact(_point: Vector3, _normal: Vector3, dv: float, _slide: float, i: int) -> void:
	if active and sp and i <= 1:
		sp.hit(i, dv)


## Every car on the road this race, the player first.
func field_cars() -> Array:
	var cars: Array = [session.car]
	cars.append_array(rivals)
	return cars


func player_place() -> int:
	return _player_place
