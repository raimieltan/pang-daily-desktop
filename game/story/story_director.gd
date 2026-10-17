class_name StoryDirector
extends Node
## Plays StoryScript beats on the stage the scene provides, in order, until the next beat needs
## another stage (then StoryMode changes scene and that scene's director carries on).
##
## Stages: "pass" (scenes/touge.gd: session, time attack, VS battle, intro, music), "hub"
## (scenes/hub.gd: session on the barangay loop), "room" (scenes/story_room.gd: a small set, no
## car) and "panel" (scenes/story_panel.gd: paper only).
## The scene hands its parts over before adding the director.

const PASS_TRACK := preload("res://maps/touge_01/track.res")
const MOTORCYCLE := preload("res://assets/vehicles/traffic/motorcycle.glb")
## Run-up before a flying sector (m), and how long a decided race stays on screen (s).
const RUN_UP := 150.0
const RESULT_HOLD := 3.0
## Where a scene at a hub place is framed from: eye and look-at as (hub x, z, height).
const SPOT_VIEWS := {
	"talyer": [Vector3(22, 128, 1.8), Vector3(26, 158, 2.0)],
	"kyo": [Vector3(118, 88, 1.7), Vector3(145, 102, 4.5)],
	"gas": [Vector3(6, -6, 2.4), Vector3(26, 24, 2.0)],
	"home": [Vector3(-70, 128, 1.8), Vector3(-78, 160, 2.0)],
}

var stage := "panel"
## The room stage's scene (sets and their camera).
var room: StoryRoom
var session: DriveSession
var time_attack: TimeAttack
var vs_battle: VsBattle
var music: MusicPlayer
## The barangay loop (hub stage).
var loop: TrackData
var dialogue: StoryDialogue
var tint: StoryTint
var board: EvidenceBoard
var weather: Weather
var recorder: StoryRecorder
var _ghost := GhostLine.new()
var _ghost_car: StoryGhost
var _objective: Label
var _flinch := 0.0
var _shaken := 0.0
var _saved_reset := Callable()
var _view: Camera3D
var _sign: SignAt8A
## Logger time (s) when Jolo shouted, for where the camera file breaks off.
var _warned_at := -1.0
## A scene is being played from the driver's seat of the parked car.
var _cabin := false


func _ready() -> void:
	dialogue = StoryDialogue.new()
	add_child(dialogue)
	# Every scene opens out of black; the first beat lifts it (_reveal).
	dialogue.black(true)
	tint = StoryTint.new()
	add_child(tint)
	board = EvidenceBoard.new()
	board.dialogue = dialogue
	add_child(board)
	_objective = MangaType.label("", 30)
	_objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_objective.position.y = 110
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var layer := CanvasLayer.new()
	layer.layer = 13
	layer.add_child(_objective)
	add_child(layer)
	if session:
		weather = Weather.new()
		weather.camera = session.camera
		add_child(weather)
		recorder = StoryRecorder.new()
		recorder.car = session.car
		recorder.track = PASS_TRACK if stage == "pass" else loop
		add_child(recorder)
	_ghost = StoryMode.ghost_line()
	if stage == "pass":
		_sign = SignAt8A.new()
		_sign.track = PASS_TRACK
		add_child(_sign)
		# Bent in the rainy season, between the first practice pass and the second.
		_sign.bent = StoryMode.beat > StoryScript.index_of("s06")
	_run.call_deferred()


func _exit_tree() -> void:
	_mute_car(false)


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	while StoryMode.active and is_inside_tree():
		var b := StoryMode.current()
		if b.get("stage", "panel") != stage:
			if not dialogue.is_black():
				await dialogue.fade(true, 0.45)
			StoryMode.goto(get_tree(), StoryMode.beat)
			return
		dialogue.set_tokens(tokens())
		await _play(b)
		if not is_inside_tree() or not StoryMode.active:
			return
		StoryMode.beat += 1
		StoryMode.reached = maxi(StoryMode.reached, StoryMode.beat)
		if StoryMode.beat >= StoryScript.BEATS.size():
			StoryMode.finish(get_tree())
			return
		StoryMode.save()


func _play(b: Dictionary) -> void:
	_conditions(b)
	await _reveal(b)
	match b["type"]:
		"chapter":
			await dialogue.chapter(b["act"], b["title"], b.get("subtitle", ""))
		"talk":
			await _settle(b)
			await dialogue.play(b["lines"], b.get("place", ""), b.get("when", ""), b.get("style", ""))
		"goto":
			await _goto(b)
		"race":
			await _race(b)
		"practice":
			await _practice(b)
		"attack":
			await _attack(b)
		"sectors":
			await _sectors(b)
		"crash":
			await _crash(b)
		"daylight":
			await _daylight(b)
		"evidence":
			await _settle(b)
			await _lines(b, "before")
			await _examine(b, b.get("cards", []))
			await _lines(b, "after")
		"end":
			await dialogue.chapter("PANG DAILY", "THE GHOST LINE", "The road continued ahead, imperfect and unrepeatable.")
	if b.has("comic_after"):
		await dialogue.comic(b["comic_after"], "black" if _cut_next() else "fade")


## The way into a beat: the stage set up behind the black (or the last page), then the beat's
## comic pages, or the black lifting. Act cards lift it themselves; the cold open keeps it.
## A memory opens on its pages and comes up warm under its period stamp; the first beat back
## cuts to black on a present-day sound and comes up on NOW.
func _reveal(b: Dictionary) -> void:
	var cold: bool = b.get("cold_open", false)
	var memory := StoryScript.memory_of(StoryMode.beat)
	tint.set_warm(memory != "")
	dialogue.set_stamp(memory if memory != "" else ("NOW" if b.has("now") else ""))
	if b["type"] in ["chapter", "end"]:
		return
	if b.has("memory"):
		await dialogue.comic(b["comic"], "black")
		await _settle(b)
		await dialogue.fade(false, 0.5)
		return
	if b.has("now"):
		dialogue.black(true)
		dialogue.sfx(str(b["now"]))
		await get_tree().create_timer(0.5).timeout
		await _settle(b)
		await dialogue.fade(false, 0.5)
		return
	if not cold:
		await _settle(b)
	else:
		# Held still behind the pages: the cold open starts the car itself.
		_hold(true)
	if b.has("comic"):
		await dialogue.comic(b["comic"], "black" if cold else "fade")
	elif dialogue.is_black() and not cold:
		await dialogue.fade(false, 0.5)


## Whether the next beat starts somewhere else (another stage, an act card): pages end on black.
func _cut_next() -> bool:
	var i := StoryMode.beat + 1
	if i >= StoryScript.BEATS.size():
		return true
	var n: Dictionary = StoryScript.BEATS[i]
	return n.get("stage", "panel") != stage or n["type"] == "chapter" or n.get("cold_open", false)


## The player's own record, for {tokens} in lines and cards.
func tokens() -> Dictionary:
	var t := { "ghost_time": TimeAttackRun.format_time(_ghost.time) if _ghost.valid() else "--:--.---" }
	t["crash_cut"] = "%.1f s" % float(StoryMode.record.get("camera_cut", 0.0))
	return t


func _lines(b: Dictionary, key: String) -> void:
	var lines: Array = b.get(key, [])
	if not lines.is_empty():
		await dialogue.play(lines, b.get("place", ""), b.get("when", ""))


# --- Stage control ----------------------------------------------------------------------------


## The present after the crash: rain and an overcast sky on every talk, evidence and drive-to
## beat that sets no weather of its own. Drive beats keep theirs (the trials are dry evidence).
const PRESENT := { "rain": 0.4, "wet": 0.7, "night_value": 0.3 }


## Night (0..1), rain and wet for a beat: its own keys, else the present-day default outside a
## memory for scene beats, else clear.
static func conditions_for(b: Dictionary, in_memory: bool) -> Dictionary:
	var own := b.has("rain") or b.has("wet") or b.has("night") or b.has("night_value")
	var present: bool = not in_memory and not own and str(b.get("type", "")) in ["talk", "evidence", "goto"]
	var rain := float(b.get("rain", PRESENT["rain"] if present else 0.0))
	var night := 1.0 if b.get("night", false) else float(b.get("night_value", PRESENT["night_value"] if present else 0.0))
	return { "night": night, "rain": rain, "wet": float(b.get("wet", PRESENT["wet"] if present else (1.0 if rain > 0.0 else 0.0))) }


## Night, rain and wet road for the beat (talk backdrops included).
func _conditions(b: Dictionary) -> void:
	var c := conditions_for(b, StoryScript.memory_of(StoryMode.beat) != "")
	MangaArt.apply_night(c["night"])
	if weather:
		weather.rain = c["rain"]
		weather.wet = c["wet"]
		weather.sheen = 0.0
		# Worn fronts (Ruel: "near the end"): the car the player has by then, not the one in the clip.
		weather.grip_scale = float(b.get("grip", 1.0))


## Park the car where the scene happens and keep it there; the HUD goes. A "cabin" scene plays
## from the driver's seat, looking out through the glass.
func _settle(b: Dictionary) -> void:
	if room:
		room.show_set(str(b.get("set", "")))
		dialogue.on_set = room.show_set
	if session == null:
		return
	_hold(true)
	_leave_cabin()
	if b.get("cabin", false) and b.has("spot"):
		var p: Vector3 = HubLayout.PLACES[b["spot"]]["spawn"]
		await _place({ "position": HubLayout.pos(p.x, p.y, 0.3), "heading": HubLayout.yaw(p.z) })
		_cabin = true
		session.camera.current = true
		session.camera.mode = ChaseCamera.Mode.HOOD
		weather.windscreen.residue = float(b.get("glass", 0.0))
		return
	if stage == "hub" and b.has("spot"):
		var s: Vector3 = HubLayout.PLACES[b["spot"]]["spawn"]
		await _place({ "position": HubLayout.pos(s.x, s.y, 0.3), "heading": HubLayout.yaw(s.z) })
		if SPOT_VIEWS.has(b["spot"]):
			var v: Array = SPOT_VIEWS[b["spot"]]
			_frame(HubLayout.pos(v[0].x, v[0].y, v[0].z), HubLayout.pos(v[1].x, v[1].y, v[1].z))
	elif stage == "pass" and b.get("at", "") == "overlook":
		await _place(PASS_TRACK.pose_at(StoryCourse.fatal_entry() - 35.0, 2.0))
		# Above 8A, looking down across the bend to the lower switchback.
		var eye: Vector3 = PASS_TRACK.pose_at(StoryCourse.fatal_entry() - 60.0, -4.0)["position"] + Vector3(0, 6, 0)
		var lower := StoryCourse.lower_leg()
		_frame(eye, PASS_TRACK.pose_at((lower.x + lower.y) * 0.5)["position"])


## A fixed shot for a scene (the chase camera comes back when the car is released).
func _frame(eye: Vector3, at: Vector3) -> void:
	if _view == null:
		_view = Camera3D.new()
		_view.fov = 60.0
		_view.far = 3000.0
		# The chase camera carries the manga pass; the framing shot needs it too.
		_view.compositor = session.camera.compositor
		add_child(_view)
	_view.position = eye
	_view.look_at(at)
	_view.current = true


## Teleport the car and wait until it is there (CarBody.place lands on the next physics step), so
## anything that looks up its position along the road afterwards finds the new one.
func _place(pose: Dictionary) -> void:
	session.car.place(pose["position"], pose["heading"])
	session.camera.snap.call_deferred()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


func _hold(on: bool) -> void:
	if session == null:
		return
	session.set_clean_feed(on)
	if on:
		session.input_filter = func(i: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
			i.throttle = 0.0
			i.brake = 1.0
			i.steer = 0.0
			i.handbrake = 0.0
			i.hold = true
			return i
	else:
		session.input_filter = Callable()
		_leave_cabin()
		session.camera.current = true


func _leave_cabin() -> void:
	if _cabin:
		_cabin = false
		session.camera.mode = ChaseCamera.Mode.CHASE
		weather.windscreen.residue = 0.0


func _mute_car(on: bool) -> void:
	for bus in ["Engine", "EngineOff", "Tires", "Fx"]:
		var i := AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_mute(i, on)


## Drive to a place in the barangay.
func _goto(b: Dictionary) -> void:
	await _lines(b, "lines")
	var place: Dictionary = HubLayout.PLACES[b["place"]]
	_hold(false)
	var area: Rect2 = place["area"]
	while is_inside_tree():
		var p := session.car.global_position
		var at := Vector2(p.x, -p.z)
		var to := area.get_center() - at
		_objective.text = "▶  %s   %d m" % [b.get("prompt", place["name"]), int(to.length())]
		if area.has_point(at):
			break
		await get_tree().process_frame
	_objective.text = ""
	_hold(true)


# --- Races ------------------------------------------------------------------------------------


static func field_spec(entry: Array) -> Dictionary:
	var car := CarRoster.get_car(entry[1])
	return { "name": entry[0], "car": car["name"], "model": car["model"], "preset": car["preset"],
		"paint": Color(entry[2]), "skill": float(entry[3]) }


## A VS race on Pass 1 or round the barangay loop; `require_win` runs it again until you win.
func _race(b: Dictionary) -> void:
	await _settle(b)
	await _lines(b, "before")
	var vs := vs_battle
	var made_here := false
	if b.get("course", "pass") == "loop":
		vs = VsBattle.new()
		vs.track = _loop_course()
		vs.session = session
		add_child(vs)
		made_here = true
		_saved_reset = session.reset_pose
	var field: Array = []
	for e in b["field"]:
		field.append(field_spec(e))
	vs.field_override = field
	vs.sp_rival = -1
	vs.opponents = field.size()
	var place := 0
	while true:
		_hold(false)
		if time_attack:
			time_attack.free_drive()
		vs.start()
		if b.get("trauma", false):
			_shaken = 0.0
			session.input_filter = func(i: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
				return _shake(vs._filter_input(i), vs)
		place = await vs.finished
		await get_tree().create_timer(RESULT_HOLD).timeout
		StoryMode.results[b["id"]] = { "place": place, "time": vs.run.time if vs.run else 0.0 }
		vs.stop()
		_hold(true)
		if place == 1 or not b.get("require_win", false):
			break
		await _lines(b, "lose")
	if made_here:
		vs.queue_free()
		session.reset_pose = _saved_reset
		var s: Vector3 = HubLayout.PLACES["gas"]["spawn"]
		await _place({ "position": HubLayout.pos(s.x, s.y, 0.3), "heading": HubLayout.yaw(s.z) })
	if not b.get("require_win", false):
		await _lines(b, "win" if place == 1 else "lose")
	await _lines(b, "after")


## One lap of the barangay loop as a race course (two laps of points so look-ahead never runs out).
func _loop_course() -> TrackData:
	var t := HubLayout.loop_track(2)
	var lap := t.length() / 2.0
	t.start_distance = 40.0
	t.finish_distance = 40.0 + lap
	return t


## The first return: a flash across the barrier mid-lap, and the driver flinches.
func _shake(i: VehicleTypes.DriverInput, vs: VsBattle) -> VehicleTypes.DriverInput:
	if vs.run and vs.run.phase == TimeAttackRun.Phase.RUNNING:
		var frac := (vs.run.progress - vs.track.start_distance) / (vs.track.finish_distance - vs.track.start_distance)
		if _shaken == 0.0 and frac > 0.35:
			_shaken = 1.0
			_flinch = 1.3
			dialogue.flash_white(0.4)
			dialogue.sfx("pulse")
			session.camera.add_impact(0.6)
			dialogue.subtitle("", "Headlights across the barrier.", 2.5)
	var dt := get_physics_process_delta_time()
	if _flinch > 0.0:
		_flinch -= dt
		i.throttle = 0.0
		i.brake = maxf(i.brake, 0.6)
	elif _shaken > 0.0:
		# Rhythm gone: early on the brakes, never fully back on the throttle.
		i.throttle = minf(i.throttle, 0.72)
		i.brake = minf(1.0, i.brake * 1.4)
	return i


# --- A Line Study and the Ghost Line ----------------------------------------------------------


func _practice(b: Dictionary) -> void:
	await _settle(b)
	await _lines(b, "before")
	StoryMode.record["passes"] = []
	for p in b["passes"]:
		MangaArt.apply_night(float(p.get("night", 0.0)))
		weather.rain = 0.0
		weather.wet = float(p.get("wet", 0.0))
		weather.sheen = float(p.get("sheen", 0.0))
		_sign.bent = p.get("sign", "bent") == "bent"
		dialogue.set_caption(p["label"])
		var run := await _timed_run({}, PackedFloat32Array(), "BEST")
		StoryMode.add_pass(p["label"], recorder.frames, run["splits"], run["time"])
		dialogue.set_caption("")
		_hold(true)
		await dialogue.play([p["note"]])
	weather.wet = 0.0
	weather.sheen = 0.0
	_ghost = StoryMode.ghost_line()
	StoryMode.save()
	await _lines(b, "after")


## One time-attack run from the line, recorded; returns { time, splits }.
func _timed_run(reference: Dictionary, ghost: PackedFloat32Array, label: String) -> Dictionary:
	_hold(false)
	time_attack.records = false
	time_attack.reference = reference
	time_attack.ghost_override = ghost
	time_attack.best_label = label
	var begin := func(): recorder.begin()
	time_attack.started.connect(begin)
	time_attack.restart(false)
	await time_attack.finished
	time_attack.started.disconnect(begin)
	recorder.stop()
	var out := { "time": time_attack.run.time, "splits": time_attack.run.splits }
	await get_tree().create_timer(RESULT_HOLD).timeout
	time_attack.free_drive()
	time_attack.records = true
	return out


func _need_ghost() -> bool:
	if _ghost.valid():
		return true
	await dialogue.play([["", "(No footage from A Line Study on this save. Replay Act I to record it.)"]])
	return false


func _attack(b: Dictionary) -> void:
	await _settle(b)
	await _lines(b, "before")
	if not await _need_ghost():
		return
	var label := "COMBINED BEST SECTORS" if b.get("label_clue", false) else "GHOST TIME"
	if b.get("label_clue", false):
		# The fair, missable clue: the board says what the target is, then the promo slide covers it.
		get_tree().create_timer(5.5).timeout.connect(func():
			if time_attack.hud:
				time_attack.hud.best_text("GHOST TIME  " + TimeAttackRun.format_time(_ghost.time)))
	var run := await _timed_run({ "time": _ghost.time, "splits": _ghost.splits }, _ghost.frames, label)
	StoryMode.results[b["id"]] = { "time": run["time"], "splits": Array(run["splits"]) }
	_hold(true)
	if b.has("after_cards"):
		await _examine(b, b["after_cards"])
	await _lines(b, _after_key(b, run["time"]))


## "beaten" lines replace "after" when the player's own run beat the Ghost Line: what they did
## stands, and the story never tells them otherwise.
func _after_key(b: Dictionary, time: float) -> String:
	return "beaten" if b.has("beaten") and time < _ghost.time else "after"


## Flying sectors against the ghost's own sector, then (`connect`) the whole road in one go.
func _sectors(b: Dictionary) -> void:
	await _settle(b)
	await _lines(b, "before")
	if not await _need_ghost():
		return
	var times := []
	for trial in b["trials"]:
		MangaArt.apply_night(float(trial.get("night", 0.0)))
		weather.wet = float(trial.get("wet", 0.0))
		dialogue.set_caption(trial["label"])
		var t := await _flying_sector(int(trial["sector"]))
		times.append([int(trial["sector"]), t])
		dialogue.set_caption("")
		_hold(true)
		if trial.has("note"):
			await dialogue.play([trial["note"]])
	var result := { "trials": times }
	if b.get("connect", false):
		MangaArt.apply_night(0.0)
		weather.wet = 0.0
		dialogue.set_caption("ALL OF IT  ·  ONE RUN  ·  TODAY'S ROAD")
		var run := await _timed_run({ "time": _ghost.time, "splits": _ghost.splits }, _ghost.frames, "GHOST TIME")
		dialogue.set_caption("")
		result["connected"] = run["time"]
	StoryMode.results[b["id"]] = result
	StoryMode.save()
	_hold(true)
	if b.has("after_cards"):
		await _examine(b, b["after_cards"])
	await _lines(b, _after_key(b, float(result.get("connected", INF))))


## One timed sector with a run-up; the ghost leaves the sector line when you cross it.
func _flying_sector(k: int) -> float:
	var t := PASS_TRACK
	var length := (t.finish_distance - t.start_distance) / 4.0
	var s0 := t.start_distance + k * length
	var s1 := s0 + length
	var standing := k == 0
	await _place(t.pose_at(s0 - (8.0 if standing else RUN_UP)))
	var run := TimeAttackRun.new(s0, s1, 100.0, 1)
	if not standing:
		run.countdown = INF
	var hud := time_attack.hud
	hud.visible = true
	hud.show_run({ "time": _ghost.sector_time(k) }, "GHOST S%d" % (k + 1))
	session.set_clean_feed(false)
	session.input_filter = func(i: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
		if standing and run.phase == TimeAttackRun.Phase.COUNTDOWN:
			i.brake = 1.0
			i.hold = true
		return i
	_ghost_car = _ghost_car if _ghost_car else _make_ghost_car()
	var index := t.nearest_index(session.car.global_position)
	var from_ghost := _ghost.splits[k - 1] if k > 0 else 0.0
	while is_inside_tree():
		await get_tree().physics_frame
		index = t.nearest_index(session.car.global_position, index)
		var d := index * t.spacing
		if run.phase == TimeAttackRun.Phase.COUNTDOWN and not standing and d >= s0:
			run.phase = TimeAttackRun.Phase.RUNNING
			run.countdown = 0.0
			run.progress = s0
			hud.go()
		var events := run.update(get_physics_process_delta_time(), d)
		if "go" in events:
			hud.go()
		hud.update_run(run)
		var g := _ghost.pose(from_ghost + run.time) if run.phase == TimeAttackRun.Phase.RUNNING else {}
		_ghost_car.show_pose(g)
		if "finish" in events:
			break
	hud.split(k, run.time, _ghost.sector_time(k))
	_ghost_car.show_pose({})
	await get_tree().create_timer(2.0).timeout
	hud.visible = false
	return run.time


func _make_ghost_car() -> StoryGhost:
	var g := StoryGhost.new()
	g.model_path = session.car_spec["model"]
	add_child(g)
	return g


# --- The night run ----------------------------------------------------------------------------


## The last night run (and, as `cold_open`, its fragments). The player drives until the approach to
## 8A; from there the night happens as it happened: too fast for the wet, late on the brakes, a
## sharp correction. No prompt pretends it can be avoided.
func _crash(b: Dictionary) -> void:
	var cold: bool = b.get("cold_open", false)
	var entry := StoryCourse.fatal_entry()
	MangaArt.apply_night(1.0)
	weather.rain = 1.0
	weather.wet = 1.0
	if cold:
		dialogue.black(true)
		session.camera.mode = ChaseCamera.Mode.HOOD
		await _place(PASS_TRACK.pose_at(entry - 190.0))
		session.set_clean_feed(true)
		var ai := AiDriver.new(session.car, PASS_TRACK, 1.0, 0.0)
		ai.racing = true
		session.input_filter = func(_i: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput: return ai.input()
		dialogue.fade(false, 1.2)
		_fragments()
	else:
		await _settle(b)
		await _place(PASS_TRACK.pose_at(PASS_TRACK.start_distance - 8.0))
		await _lines(b, "before")
		if not await _need_ghost():
			return
		_hold(false)
		time_attack.records = false
		time_attack.reference = { "time": _ghost.time, "splits": _ghost.splits }
		time_attack.ghost_override = _ghost.frames
		time_attack.best_label = "GHOST TIME"
		time_attack.ghost_opacity = 0.6
		var begin := func(): recorder.begin()
		time_attack.started.connect(begin, CONNECT_ONE_SHOT)
		time_attack.restart(false)
	var cues := [[PASS_TRACK.start_distance + 330.0, "JOLO", "Different here."], [PASS_TRACK.start_distance + 345.0, "PANG", "I know."],
		[PASS_TRACK.start_distance + 365.0, "JOLO", "Then don't force it."], [entry - 230.0, "JOLO", "Pang."], [entry - 150.0, "JOLO", "Pang, listen."]]
	var index := PASS_TRACK.nearest_index(session.car.global_position)
	var lights: HeadlightsRig = null
	while is_inside_tree():
		await get_tree().physics_frame
		index = PASS_TRACK.nearest_index(session.car.global_position, index)
		var d := index * PASS_TRACK.spacing
		while not cues.is_empty() and d >= cues[0][0]:
			var c: Array = cues.pop_front()
			dialogue.subtitle(c[1], c[2], 2.6)
		if lights == null and d >= entry - 170.0:
			lights = HeadlightsRig.new()
			lights.track = PASS_TRACK
			add_child(lights)
		if d >= entry - 70.0:
			break
	if not cold:
		session.replay.stop()
	await _takeover(entry)
	# The impact: a white frame, then nothing at all.
	var frames := recorder.stop() if not cold else PackedFloat32Array()
	dialogue.flash_white(0.12)
	dialogue.sfx("impact", 4.0)
	session.camera.add_impact(1.0)
	await get_tree().create_timer(0.1).timeout
	dialogue.black(true)
	_mute_car(true)
	weather.rain = 0.0
	if music:
		music.stop_music(0.05)
	if time_attack:
		time_attack.hud.visible = false
		time_attack.ghost_opacity = -1.0
	if not cold:
		StoryMode.record["crash"] = StoryMode.pack(frames)
		# The camera card is cracked: its file stops just after Jolo's warning; the logger runs on
		# to the end.
		var end := frames.size() / GhostLine.STRIDE / GhostLine.HZ
		StoryMode.record["camera_cut"] = minf(end, _warned_at + 0.4) if _warned_at >= 0.0 else maxf(0.0, end - 0.9)
		StoryMode.save()
	await get_tree().create_timer(2.8).timeout
	if not cold:
		dialogue.sfx("pulse")
		await get_tree().create_timer(1.6).timeout
	if lights:
		lights.queue_free()
	if time_attack:
		time_attack.free_drive()
	session.camera.mode = ChaseCamera.Mode.CHASE
	_mute_car(false)


## The cold open is fragments: hard black cuts across the approach, never the whole sequence.
func _fragments() -> void:
	for gap in [1.1, 0.9, 1.3, 0.7, 0.8]:
		await get_tree().create_timer(gap).timeout
		if not is_inside_tree():
			return
		await dialogue.cut(0.18)


func _takeover(entry: float) -> void:
	var ai := AiDriver.new(session.car, PASS_TRACK, 1.0, 0.0)
	ai.racing = true
	# Shared with the input filter (lambdas capture locals by value): phase 0 chasing the
	# reference entry, 1 late on the brakes, 2 the correction; `at` is when braking began.
	var st := { "phase": 0, "t": 0.0, "at": -1.0, "hit": false }
	var on_hit := func(_p, _n, dv: float, _s): if dv > 2.0: st["hit"] = true
	session.car.wall_contact.connect(on_hit)
	session.input_filter = func(_i: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
		var i := ai.input()
		if st["phase"] == 0:
			# Flat out where the dry practice was already braking.
			i.throttle = 1.0
			i.brake = 0.0
			if ai.distance >= entry - 24.0:
				st["phase"] = 1
				st["at"] = st["t"]
		if st["phase"] == 1:
			i.throttle = 0.0
			i.brake = 0.9
			if st["t"] - st["at"] > 0.45:
				st["phase"] = 2
		if st["phase"] == 2:
			# The wet patch on the outside edge takes the rear; the hands answer too hard.
			var k: float = st["t"] - st["at"] - 0.45
			i.throttle = 0.0
			i.brake = 0.25
			i.steer = -0.95 if k < 0.35 else 1.0
		return i
	session.camera.mode = ChaseCamera.Mode.HOOD
	var warned := false
	while is_inside_tree():
		await get_tree().physics_frame
		st["t"] += get_physics_process_delta_time()
		if st["phase"] == 2:
			weather.grip_scale = 0.55
			if not warned:
				warned = true
				dialogue.subtitle("JOLO", "Drive the road!", 2.0)
				_warned_at = recorder.frames.size() / GhostLine.STRIDE / GhostLine.HZ
		var p := session.car.global_position
		var off := absf(PASS_TRACK.lateral_offset(p, PASS_TRACK.nearest_index(p)))
		var since: float = st["t"] - st["at"] if st["at"] >= 0.0 else 0.0
		if st["hit"] or off > PASS_TRACK.half_width + 1.6 or since > 2.6 or st["t"] > 9.0:
			break
	session.car.wall_contact.disconnect(on_hit)
	weather.grip_scale = 1.0
	_hold(true)


# --- The daylight road ------------------------------------------------------------------------


func _daylight(b: Dictionary) -> void:
	var t := PASS_TRACK
	await _settle(b)
	await _place(t.pose_at(t.start_distance - 8.0))
	await _lines(b, "before")
	time_attack.free_drive()
	if music:
		music.stop_music()
	var entry := StoryCourse.fatal_entry()
	var truck := RoadsideLife.Mover.new()
	truck.track = t
	truck.span = Vector2(entry - 200.0, StoryCourse.fatal_exit() + 160.0)
	truck.speed = 6.0
	truck.lane = 2.4
	truck.shoulder = 3.0
	truck.distance = truck.span.y
	truck.dir = -1
	truck.setup(MOTORCYCLE, Color(0.55, 0.12, 0.1), 0.39)
	add_child(truck)
	_hold(false)
	session.set_clean_feed(true)
	_ghost_car = _ghost_car if _ghost_car else (_make_ghost_car() if _ghost.valid() else null)
	var index := t.nearest_index(session.car.global_position)
	var ghost_t := -1.0
	var ghost_life := 0.0
	while is_inside_tree():
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		truck.step(dt, get_tree().get_nodes_in_group(&"cars"))
		index = t.nearest_index(session.car.global_position, index)
		var d := index * t.spacing
		if _ghost_car and ghost_t < 0.0 and d >= entry - 240.0:
			ghost_t = StoryCourse.ghost_time_at(_ghost, d + 20.0)
		if _ghost_car and ghost_t >= 0.0 and ghost_life < 11.0:
			ghost_t += dt
			ghost_life += dt
			# The old line, brightest at the bend; then it goes on without you and fades.
			_ghost_car.opacity = clampf(minf(ghost_life * 0.5, (11.0 - ghost_life) * 0.25), 0.0, 0.55)
			_ghost_car.show_pose(_ghost.pose(ghost_t))
		elif _ghost_car:
			_ghost_car.show_pose({})
		if d >= t.finish_distance - 12.0:
			break
	_hold(true)
	truck.queue_free()
	await _lines(b, "after")


# --- Evidence ---------------------------------------------------------------------------------


func _examine(b: Dictionary, cards: Array) -> void:
	if cards.is_empty():
		return
	board.context = _evidence_context()
	var beat := b.duplicate()
	beat["cards"] = cards
	if not b.has("question") or cards != b.get("cards", []):
		beat.erase("question")
	await board.examine(beat)


func _evidence_context() -> Dictionary:
	var c := { "ghost": _ghost, "track": PASS_TRACK, "tokens": tokens() }
	var passes: Array = StoryMode.record.get("passes", [])
	if _ghost.valid() and passes.size() > _ghost.picks[0]:
		c["raw0"] = StoryMode.unpack(passes[_ghost.picks[0]]["frames"])
	if not passes.is_empty():
		c["dry"] = StoryMode.unpack(passes[0]["frames"])
	c["crash"] = StoryMode.unpack(StoryMode.record.get("crash", ""))
	c["camera_cut"] = float(StoryMode.record.get("camera_cut", -1.0))
	if _ghost.valid():
		c["board"] = _board_rows()
		c["notes"] = _notes_rows()
		c["trials"] = _trial_rows()
	return c


## The challenge board: drivers who matched a sector, nobody who matched the sum.
func _board_rows() -> Array:
	var rows := []
	var gs := []
	for k in 4:
		gs.append(_ghost.sector_time(k))
	var drivers := [["NICO", [0.04, 0.9, 0.7, 0.8]], ["ATE LIZA", [0.6, 0.02, 1.1, 0.9]], ["BUKO", [0.9, 1.3, 0.8, 0.03]]]
	for dr in drivers:
		var row := [dr[0]]
		var total := 0.0
		for k in 4:
			var v: float = gs[k] + dr[1][k]
			row.append("%.2f" % v)
			total += v
		row.append(TimeAttackRun.format_time(total))
		rows.append(row)
	var mine: Dictionary = StoryMode.results.get("s09", {})
	var sp: Array = mine.get("splits", [])
	if sp.size() >= 4:
		var row := ["YOU"]
		for k in 4:
			row.append("%.2f" % (float(sp[k]) - (float(sp[k - 1]) if k > 0 else 0.0)))
		row.append(TimeAttackRun.format_time(float(mine["time"])))
		rows.append(row)
	var ghost_row := ["GHOST"]
	for k in 4:
		ghost_row.append("%.2f" % gs[k])
	ghost_row.append(TimeAttackRun.format_time(_ghost.time))
	rows.append(ghost_row)
	return rows


func _notes_rows() -> Array:
	var rows := []
	var trials: Array = StoryMode.results.get("s18", {}).get("trials", [])
	for tr in trials:
		var k := int(tr[0])
		var mine := float(tr[1])
		var g := _ghost.sector_time(k)
		rows.append(["S%d" % (k + 1), "%.2f" % g, "%.2f" % mine, "%+.2f" % (mine - g)])
	return rows


func _trial_rows() -> Array:
	var r: Dictionary = StoryMode.results.get("s26", {})
	var rows := []
	var sum := 0.0
	for tr in r.get("trials", []):
		rows.append(["SECTOR %d  (its own conditions)" % (int(tr[0]) + 1), "%.2f" % float(tr[1])])
		sum += float(tr[1])
	if r.has("connected"):
		rows.append(["YOUR ONE CONTINUOUS RUN", TimeAttackRun.format_time(float(r["connected"]))])
	rows.append(["GHOST TIME (BEST SECTORS, 3 PASSES)", TimeAttackRun.format_time(_ghost.time)])
	rows.append(["NO SINGLE PASS EVER DROVE", "ALL OF IT"])
	return rows


## The chevron board on the outside of 8A: straight in the first practice pass, bent inward on its
## post in the later ones (and ever after). The clip's sectors disagree about it.
class SignAt8A extends Node3D:
	var track: TrackData
	var bent := false:
		set(v):
			bent = v
			if _board:
				_board.rotation = Vector3(deg_to_rad(28.0), deg_to_rad(-34.0), deg_to_rad(9.0)) if v else Vector3.ZERO
	var _board: Node3D

	func _ready() -> void:
		var pose := track.pose_at(StoryCourse.fatal_entry() + 6.0, -4.4)
		global_position = pose["position"]
		# Facing the cars coming down into the bend.
		rotation.y = pose["heading"] + PI
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.05
		cyl.height = 2.0
		post.mesh = cyl
		post.position.y = 1.0
		post.material_override = MangaArt.world_preset("post")
		add_child(post)
		_board = Node3D.new()
		_board.position.y = 1.9
		add_child(_board)
		var face := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.3, 0.8, 0.05)
		face.mesh = box
		var m := MangaArt.world_preset("board")
		m.set_shader_parameter("pattern_mode", 1)
		m.set_shader_parameter("pattern_dir", 1.0)
		face.material_override = m
		_board.add_child(face)
		bent = bent


## Lights on the lower switchback, coming uphill: from 8A they slide through the trees and, for a
## moment, look like a car beside you. Two warm spots and their lamp faces.
class HeadlightsRig extends Node3D:
	var track: TrackData
	var distance := 0.0
	const SPEED := 8.0

	func _ready() -> void:
		distance = StoryCourse.lower_leg().y + 10.0
		for side in [-0.7, 0.7]:
			var spot := SpotLight3D.new()
			spot.light_color = MangaArt.HEADLAMP
			spot.light_energy = 7.0
			spot.spot_range = 55.0
			spot.spot_angle = 26.0
			spot.position = Vector3(side, 0.7, -2.0)
			spot.rotation.x = 0.06
			add_child(spot)
			var lamp := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.22
			sphere.height = 0.44
			lamp.mesh = sphere
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.95, 0.8)
			lamp.material_override = m
			lamp.position = Vector3(side, 0.7, -2.1)
			add_child(lamp)

	func _physics_process(delta: float) -> void:
		# Uphill, and never as far as the bend: it stays on the lower road.
		distance = maxf(StoryCourse.lower_leg().x + 12.0, distance - SPEED * delta)
		var pose := track.pose_at(distance, -1.8)
		global_position = pose["position"]
		# Driving uphill: facing back along the road.
		rotation.y = pose["heading"] + PI
