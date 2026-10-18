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
## The hub scene (hub stage): it spawns the regulars parked at the gas station during free roam.
var hub: Node
## The road the current drive is on (probes put their AI on it).
var drive_track: TrackData
## The talyer's garage and Kapitan's board (free roam, and talk beats with "garage").
var garage: StoryGarage
var _prompt: Label
var _money: Label
var _toast_left := 0.0


func _ready() -> void:
	# The car is heard from the first frame: the title screen mutes the car buses while it is up and
	# the story's scene change skips the menu's unmute (a long free roam stayed silent).
	_mute_car(false)
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
	_prompt = MangaType.label("", 28)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.position.y = -150
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_prompt)
	_money = MangaType.label("", 24, MangaType.caption())
	_money.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_money.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_money.position = Vector2(-24, 124)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_money)
	garage = StoryGarage.new()
	garage.car_changed.connect(_fit_car)
	add_child(garage)
	# Pass 1 has the game menu's pause; every other stage gets the story's own.
	if stage != "pass":
		add_child(StoryPause.new())
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
	if not StoryMode.side.is_empty():
		# A mountain event picked off Kapitan's board: run it here, then back to the roam.
		if StoryMode.side.get("stage", "pass") == stage:
			await _side_event(StoryMode.side)
		StoryMode.side = {}
		StoryMode.roam_from = "gas"
		if not is_inside_tree():
			return
		if not dialogue.is_black():
			await dialogue.fade(true, 0.45)
		StoryMode.goto(get_tree(), StoryMode.beat)
		return
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
	_fit_car()
	await _reveal(b)
	match b["type"]:
		"chapter":
			await dialogue.chapter(b["act"], b["title"], b.get("subtitle", ""))
		"talk":
			await _settle(b)
			await _lines(b, "lines", b.get("style", ""))
			if b.get("garage", false):
				await _open_garage("shop")
				await _lines(b, "after")
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
		"roam":
			await _roam(b)
		"test":
			await _test(b)
		"trial":
			await _trial(b)
		"final":
			await _final(b)
		"end":
			await dialogue.chapter("PANG DAILY", "THE GHOST LINE", "The road continued ahead, imperfect and unrepeatable.")
	_write_down(b)
	if b.has("comic_after"):
		await dialogue.comic(b["comic_after"], "black" if _cut_next() else "fade")
	await _exit(b)


## The way out of a beat (its "exit", and the next beat's "enter" when that is heard first):
##   tail   seconds held on the last shot (skippable after 1 s; the crash runs its own)
##   sound  heard from here into the next beat, faded over `carry` s (the L-cut); loop: true
##   cut    a hard cut instead of a fade (so is any beat back to the present: "now")
##   fade   seconds of the fade out (it fades anyway when the next beat is on another stage)
## The next beat's "enter": sound (+ db, loop) starts `lead` s before the cut (the J-cut); a loop
## runs until this beat ends, or only until its image is up with until: "reveal"; head holds
## its first shot before anything is said.
func _exit(b: Dictionary) -> void:
	var ex: Dictionary = b.get("exit", {})
	var bridge := StoryBridge.node()
	if ex.has("tail"):
		await dialogue.hold(float(ex["tail"]))
	var own: Dictionary = b.get("enter", {})
	if own.has("sound") and own.get("loop", false):
		bridge.release(own["sound"], float(own.get("carry", 1.5)))
	if ex.has("sound"):
		bridge.play(ex["sound"], float(ex.get("db", -8.0)), ex.get("loop", false))
		if ex.get("loop", false):
			get_tree().create_timer(0.05).timeout.connect(bridge.release.bind(ex["sound"], float(ex.get("carry", 2.0))))
	var i := StoryMode.beat + 1
	if i >= StoryScript.BEATS.size():
		return
	var next: Dictionary = StoryScript.BEATS[i]
	var en: Dictionary = next.get("enter", {})
	if en.has("sound"):
		bridge.play(en["sound"], float(en.get("db", -8.0)), en.get("loop", false))
		await get_tree().create_timer(float(en.get("lead", 0.8))).timeout
	if dialogue.is_black():
		return
	if ex.get("cut", false) or en.get("cut", false) or next.has("now"):
		dialogue.black(true)
	elif next.get("stage", "panel") != stage or ex.has("fade"):
		await dialogue.fade(true, float(ex.get("fade", 0.45)))


## The way into a beat: the stage set up behind the black (or the last page), then the beat's
## comic pages, or the black lifting. Act cards lift it themselves; the cold open keeps it.
## A memory opens on its pages and comes up warm under its period stamp; the first beat back
## cuts to black on a present-day sound and comes up on NOW.
func _reveal(b: Dictionary) -> void:
	await _reveal_shot(b)
	var en: Dictionary = b.get("enter", {})
	if en.get("until", "") == "reveal" and en.has("sound"):
		StoryBridge.node().release(en["sound"], float(en.get("carry", 1.5)))
	if en.has("head"):
		await dialogue.hold(float(en["head"]))


## The tint and the stamp change with the picture: under the black, or on the cut.
func _look(memory: String, now: bool) -> void:
	tint.set_warm(memory != "")
	dialogue.set_stamp(memory if memory != "" else ("NOW" if now else ""))


func _reveal_shot(b: Dictionary) -> void:
	var cold: bool = b.get("cold_open", false)
	var memory := StoryScript.memory_of(StoryMode.beat)
	if b["type"] in ["chapter", "end"]:
		_look(memory, false)
		return
	if b.has("memory"):
		# The pages are still the present; the past comes up warm out of their black.
		await dialogue.comic(b["comic"], "black")
		_look(memory, false)
		await _settle(b)
		await dialogue.fade(false, 0.5)
		return
	if b.has("now"):
		# A hard cut back: the present-day sound and the picture land on the same frame.
		dialogue.black(true)
		_look("", true)
		await _settle(b)
		dialogue.sfx(str(b["now"]))
		dialogue.black(false)
		return
	_look(memory, false)
	if not cold:
		await _settle(b)
	else:
		# Held still behind the pages: the cold open starts the car itself.
		_hold(true)
	# Back in a roam from a mountain event: the roam's pages were seen on the way in.
	var back: bool = b["type"] == "roam" and StoryMode.roam_from != ""
	if b.has("comic") and not back:
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
	var t := { "ghost_time": TimeAttackRun.format_time(StoryMode.posted_time(_ghost.time)) if _ghost.valid() else "--:--.---" }
	t["cut_time"] = TimeAttackRun.format_time(_ghost.time) if _ghost.valid() else "--:--.---"
	t["crash_cut"] = "%.1f s" % float(StoryMode.record.get("camera_cut", 0.0))
	var car := StoryMode.car()
	t["front_wear"] = "%d%%" % roundi(CarParts.wear(car, "front") * 100.0)
	t["wallet"] = "₱" + StoryGarage._pesos(StoryMode.wallet())
	t["owed"] = "₱" + StoryGarage._pesos(StoryMode.owed())
	t["rain_price"] = "₱" + StoryGarage._pesos(StoryShop.price("rain_set"))
	return t


func _lines(b: Dictionary, key: String, style := "") -> void:
	var lines := spoken(b.get(key, []))
	if not lines.is_empty():
		await dialogue.play(lines, b.get("place", ""), b.get("when", ""), style)


## The lines that apply to this player: a line with a third element plays only when that
## condition holds on their record (see `holds`).
static func spoken(lines: Array) -> Array:
	var out := []
	for line in lines:
		if line is Array and line.size() == 3:
			if holds(str(line[2])):
				out.append([line[0], line[1]])
		else:
			out.append(line)
	return out


## A condition on the player's record: "won:NAME", "list" (Dante's list), "bought:part",
## "cash:N" (the wallet holds N), "patch" (went into the damp in the final), any rep flag;
## a leading "!" negates.
static func holds(cond: String) -> bool:
	if cond.begins_with("!"):
		return not holds(cond.substr(1))
	if cond.begins_with("cash:"):
		return StoryMode.wallet() >= int(cond.substr(5))
	if cond == "patch":
		return bool(StoryMode.results.get("s34a", {}).get("entered_patch", false))
	return StoryMode.flag(cond)


## What a beat writes down once it's played: Jolo's commitments (`commit`), Ruel's bill (`bill`),
## flags (`flag`, e.g. the rain set ordered at s12).
func _write_down(b: Dictionary) -> void:
	if b.has("commit"):
		StoryMode.commitments.append(b["commit"].duplicate())
	if b.has("bill"):
		StoryMode.bill(str(b["bill"][0]), int(b["bill"][1]))
	if b.has("flag"):
		StoryMode.set_flag(str(b["flag"]))


# --- Stage control ----------------------------------------------------------------------------


## The present after the crash: rain and an overcast sky on every talk and evidence beat that
## sets no weather of its own, until Act V. Drive beats (drive-to included) keep theirs: the
## trials are dry evidence.
const PRESENT := { "rain": 0.4, "wet": 0.7, "night_value": 0.3 }


## Night (0..1), rain and wet for a beat: its own keys, else the present-day default outside a
## memory for scene beats before the ending, else clear.
static func conditions_for(b: Dictionary, in_memory: bool, ending := false) -> Dictionary:
	# `night` is only the light: a present-day scene at night still rains. A beat's own rain, wet
	# or night_value (a chosen time of day) are its own weather.
	var own := b.has("rain") or b.has("wet") or b.has("night_value")
	var present: bool = not in_memory and not ending and not own and str(b.get("type", "")) in ["talk", "evidence"]
	var rain := float(b.get("rain", PRESENT["rain"] if present else 0.0))
	var night := 1.0 if b.get("night", false) else float(b.get("night_value", PRESENT["night_value"] if present else 0.0))
	return { "night": night, "rain": rain, "wet": float(b.get("wet", PRESENT["wet"] if present else (1.0 if rain > 0.0 else 0.0))) }


## Night, rain and wet road for the beat (talk backdrops included).
func _conditions(b: Dictionary) -> void:
	var c := conditions_for(b, StoryScript.memory_of(StoryMode.beat) != "", StoryMode.beat >= StoryScript.index_of("a5_card"))
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
	if stage == "hub" and b["type"] == "roam":
		# Back from a race in the roam: on the forecourt. Else where the beat starts, if anywhere.
		var from: String = StoryMode.roam_from if StoryMode.roam_from != "" else str(b.get("spot", ""))
		if from != "":
			var r: Vector3 = HubLayout.PLACES[from]["spawn"]
			await _place({ "position": HubLayout.pos(r.x, r.y, 0.3), "heading": HubLayout.yaw(r.z) })
	elif stage == "hub" and b.has("spot"):
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
		_show_drive_hud()


## The gauges are hidden when a story scene loads (the intro and the menu own them), so the
## clean feed's "restore" after dialogue restored them hidden: a drive beat shows them.
func _show_drive_hud() -> void:
	session.gauges.visible = true
	session.day_night.visible = true


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


## The end of a drive: off the throttle and onto the brakes by degrees, the driver still steering,
## so the car rolls to a stop instead of being caught by the next scene.
func _coast(seconds: float) -> void:
	var prev := session.input_filter
	var st := { "t": 0.0 }
	session.input_filter = func(i: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
		if prev.is_valid():
			i = prev.call(i)
		st["t"] += get_physics_process_delta_time()
		i.throttle = 0.0
		i.brake = maxf(i.brake, clampf(st["t"] / maxf(seconds, 0.1), 0.0, 1.0) * 0.7)
		i.handbrake = 0.0
		return i
	await get_tree().create_timer(seconds).timeout
	session.input_filter = prev


## Arriving at a place: the car rolls to a stop while the camera drifts to the scene's shot; the
## car is moved to its mark under a short dip to black (the next beat comes up out of it).
func _ease_into(spot: String) -> void:
	var v: Array = SPOT_VIEWS[spot]
	var from := get_viewport().get_camera_3d().global_transform
	_frame(HubLayout.pos(v[0].x, v[0].y, v[0].z), HubLayout.pos(v[1].x, v[1].y, v[1].z))
	var to := _view.global_transform
	_view.global_transform = from
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) \
		.tween_property(_view, "global_transform", to, 1.4)
	await _coast(1.4)
	await dialogue.fade(true, 0.3)


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
	var i := StoryMode.beat + 1
	var next: Dictionary = StoryScript.BEATS[i] if i < StoryScript.BEATS.size() else {}
	if next.get("spot", "") == b["place"] and SPOT_VIEWS.has(b["place"]):
		await _ease_into(b["place"])
	_hold(true)


# --- Races ------------------------------------------------------------------------------------


static func field_spec(entry: Array) -> Dictionary:
	var car := CarRoster.get_car(entry[1])
	return { "name": entry[0], "car": car["name"], "model": car["model"], "preset": car["preset"],
		"paint": Color(entry[2]), "skill": float(entry[3]) }


## A VS race on Pass 1 or round the barangay loop; `require_win` runs it again until you win.
## Money: `entry` is paid first (StoryMode.pay_entry: never blocks), `purse` pays by place,
## `bet` is a side bet won or lost; `heat` races a heat first; `ghost` runs the overlay ahead.
func _race(b: Dictionary) -> void:
	await _settle(b)
	await _lines(b, "before")
	_pay_in(b)
	if b.has("heat"):
		dialogue.set_caption("HEAT")
		var heat := await _race_core(b, _field(b["heat"]), false)
		dialogue.set_caption("")
		StoryMode.results[b["id"] + "_heat"] = { "place": heat }
		await _lines(b, "heat_lines")
		dialogue.set_caption("FINAL")
	var entries: Array = b["field"].duplicate()
	for cond in b.get("field_if", {}):
		if holds(cond):
			entries.append_array(b["field_if"][cond])
	var place := await _race_core(b, _field(entries), b.get("require_win", false))
	dialogue.set_caption("")
	_pay_out(b, place)
	if b["field"].size() == 1 and place == 1:
		StoryMode.set_flag("won:" + str(b["field"][0][0]))
	if b.has("podium_flag") and place <= 3:
		StoryMode.set_flag(str(b["podium_flag"]))
	StoryMode.save()
	if not b.get("require_win", false):
		await _lines(b, "win" if place == 1 else "lose")
	await _lines(b, "after")


static func _field(entries: Array) -> Array:
	var out := []
	for e in entries:
		out.append(field_spec(e))
	return out


## The race itself, run until it is won when `require_win`; returns the finishing place.
func _race_core(b: Dictionary, field: Array, require_win: bool) -> int:
	var vs := vs_battle
	var made_here := false
	var laps := int(b.get("laps", 1))
	if b.get("course", "pass") == "loop":
		vs = VsBattle.new()
		vs.track = _loop_course(laps)
		vs.session = session
		add_child(vs)
		made_here = true
		_saved_reset = session.reset_pose
	drive_track = vs.track
	vs.field_override = field
	vs.sp_rival = -1
	vs.opponents = field.size()
	var place := 0
	var tries := 0
	while true:
		_hold(false)
		if time_attack:
			time_attack.free_drive()
		if tries > 0:
			# "They'll let you run it back": each rerun of a race that must be won, the field
			# eases off a little, so nobody is stuck behind it.
			for spec in field:
				spec["skill"] = maxf(0.6, float(spec["skill"]) - 0.02)
			vs.field_override = field
		tries += 1
		vs.start()
		if b.get("trauma", false):
			_shaken = 0.0
			session.input_filter = func(i: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
				return _shake(vs._filter_input(i), vs)
		if b.get("ghost", false) and _ghost.valid():
			_overlay(vs)
		place = await vs.finished
		await _coast(RESULT_HOLD)
		StoryMode.results[b["id"]] = { "place": place, "time": vs.run.time if vs.run else 0.0 }
		vs.stop()
		_hold(true)
		if place == 1 or not require_win:
			break
		await _lines(b, "lose")
	# Wear once for the race, however many reruns it took (the story's night happened once).
	_wear(laps * (StoryMode.LOOP_KM if made_here else StoryMode.PASS_KM))
	if made_here:
		vs.queue_free()
		session.reset_pose = _saved_reset
		var s: Vector3 = HubLayout.PLACES["gas"]["spawn"]
		await _place({ "position": HubLayout.pos(s.x, s.y, 0.3), "heading": HubLayout.yaw(s.z) })
	return place


## The Ghost Line running ahead of the field (Night 3): the car in the clip at the cut's pace.
func _overlay(vs: VsBattle) -> void:
	_ghost_car = _ghost_car if _ghost_car else _make_ghost_car()
	_ghost_car.opacity = 0.45
	while is_inside_tree() and vs.active:
		await get_tree().physics_frame
		var running := vs.run and vs.run.phase == TimeAttackRun.Phase.RUNNING
		_ghost_car.show_pose(_ghost.pose(vs.run.time) if running else {})
	if _ghost_car:
		_ghost_car.show_pose({})


## One lap (or `laps`) of the barangay loop as a race course, with a lap of points to spare so
## look-ahead never runs out.
func _loop_course(laps := 1) -> TrackData:
	var t := HubLayout.loop_track(laps + 1)
	var lap := t.length() / float(laps + 1)
	t.start_distance = 40.0
	t.finish_distance = 40.0 + lap * laps
	return t


# --- Money and the car ------------------------------------------------------------------------


## The beat's car on the session: the timeline's build (or the line-study snapshot) and its setup.
func _fit_car() -> void:
	if session == null or session.car == null:
		return
	var car := StoryMode.car()
	session.car.set_build(car)
	session.car.set_setup(car.get("setup", {}))


## Tire wear for a drive just done, then the car as it now is.
func _wear(km: float) -> void:
	StoryMode.drive(km)
	_fit_car()


## A beat's entry: the posted fee, more for a driver off Dante's list where it says so.
static func entry_for(b: Dictionary) -> int:
	var fee := int(b.get("entry", 0))
	if fee > 0 and b.has("off_list") and not StoryMode.flag("list"):
		fee += int(b["off_list"])
	return fee


func _pay_in(b: Dictionary) -> void:
	var fee := entry_for(b)
	if fee <= 0:
		return
	var had := StoryMode.wallet()
	StoryMode.pay_entry(fee, true, str(b.get("title", "ENTRY")))
	_toast("ENTRY  ₱%s%s" % [StoryGarage._pesos(fee), "" if had >= fee else ("   ·   JOLO COVERED IT" if StoryMode.timeline() == "memory" else "   ·   ON RUEL'S BILL")])


## What a race paid: the purse by place, the side bet either way.
func _pay_out(b: Dictionary, place: int) -> void:
	var won := 0
	if b.has("purse"):
		won = StoryBoard.payout(b["purse"], place, b.get("kind", ""))
	if b.has("bet"):
		var stake := mini(int(b["bet"]), StoryMode.wallet()) if place != 1 else int(b["bet"])
		if place == 1:
			won += stake
		else:
			StoryMode.spend(stake)
			_toast("SIDE BET  -₱%s" % StoryGarage._pesos(stake))
	if won > 0:
		StoryMode.earn(won)
		_toast("PURSE  ₱%s   ·   WALLET  ₱%s" % [StoryGarage._pesos(won), StoryGarage._pesos(StoryMode.wallet())])


## A short line under the top of the screen (money in and out).
func _toast(text: String) -> void:
	_objective.text = text
	_toast_left = 3.5
	var me := text
	get_tree().create_timer(3.5).timeout.connect(func():
		if _objective.text == me:
			_objective.text = "")


func _open_garage(tab: String) -> void:
	if StoryDialogue.auto_advance > 0.0:
		_auto_shop()
		return
	_hold(true)
	_money.text = ""
	await garage.open_garage(tab)
	_fit_car()


## Probes: buy the cheapest part Ruel would choose that the wallet covers.
func _auto_shop() -> void:
	for it in StoryShop.ITEMS:
		if it["kind"] == "ruel" and StoryShop.status(it["id"]) == StoryShop.Status.BUY and StoryShop.price(it["id"]) <= StoryMode.wallet() \
				and it["id"] != "rain_set":
			StoryShop.buy(it["id"])
			_fit_car()
			return


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
	# The car in the clip: what the evidence later runs on (R8, R16).
	StoryMode.take_snapshot()
	drive_track = PASS_TRACK
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
		_wear(StoryMode.PASS_KM)
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
	await _coast(RESULT_HOLD)
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
	_pay_in(b)
	drive_track = PASS_TRACK
	var label := "COMBINED BEST SECTORS" if b.get("label_clue", false) else "GHOST TIME"
	var target := _target(b)
	if b.get("label_clue", false):
		# The fair, missable clue: the board says what the target is, then the promo slide covers it.
		get_tree().create_timer(5.5).timeout.connect(func():
			if time_attack.hud:
				time_attack.hud.best_text("GHOST TIME  " + TimeAttackRun.format_time(target["time"])))
	var run := await _timed_run(target, _ghost.frames, label)
	_wear(StoryMode.PASS_KM)
	StoryMode.results[b["id"]] = { "time": run["time"], "splits": Array(run["splits"]) }
	var key := after_key(b, run["time"], target, _ghost.time)
	if key == "beaten" and b.get("posted", false):
		# Beaten in public: by the time the board is read, Dante has posted a time under yours.
		StoryMode.repost(run["time"])
		_keep_repost()
	# The purse goes to a run under the target; anything else gets the ₱1,000 for finishing.
	if b.has("purse"):
		_pay_out(b, 1 if run["time"] < float(target["time"]) else 99)
	if key == "beaten" and b.has("bounty"):
		StoryMode.earn(int(b["bounty"]))
		_toast("GHOST BOUNTY  ₱%s" % StoryGarage._pesos(int(b["bounty"])))
	StoryMode.save()
	_hold(true)
	if b.has("after_cards"):
		await _examine(b, b["after_cards"])
	await _lines(b, key)


## Every number Dante ever posted, oldest first (S29's board, S30's table).
func _keep_repost() -> void:
	var list: Array = StoryMode.record.get("reposts", [])
	list.append(float(StoryMode.record["posted"]))
	StoryMode.record["reposts"] = list


## What a drive chases: the cut itself, or (`posted`) the number Dante put on it, the splits
## scaled down to it. The car in the clip always drives the cut.
func _target(b: Dictionary) -> Dictionary:
	return target_for(_ghost, b.get("posted", false))


static func target_for(g: GhostLine, posted: bool) -> Dictionary:
	if not posted or not g.valid():
		return { "time": g.time, "splits": g.splits }
	var t := StoryMode.posted_time(g.time)
	var splits := PackedFloat64Array()
	for v in g.splits:
		splits.append(v * t / g.time)
	return { "time": t, "splits": splits }


## Which lines follow a run. "beaten" when the player's run beat the target: what they did stands,
## and the story never tells them otherwise. "ahead" when they beat the car in the clip but not the
## clock Dante put on it (the board says otherwise, and that is the clue). Else "after".
static func after_key(b: Dictionary, time: float, target: Dictionary, cut: float) -> String:
	if b.has("beaten") and time < float(target["time"]):
		return "beaten"
	if b.has("ahead") and time < cut:
		return "ahead"
	return "after"


## Flying sectors against the ghost's own sector, then (`connect`) the whole road in one go.
func _sectors(b: Dictionary) -> void:
	await _settle(b)
	await _lines(b, "before")
	if not await _need_ghost():
		return
	_pay_in(b)
	drive_track = PASS_TRACK
	var times := []
	for trial in b["trials"]:
		MangaArt.apply_night(float(trial.get("night", 0.0)))
		weather.wet = float(trial.get("wet", 0.0))
		dialogue.set_caption(trial["label"])
		var t := await _flying_sector(int(trial["sector"]))
		_wear(StoryMode.PASS_KM * 0.35)
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
		var run := await _timed_run(_target(b), _ghost.frames, "GHOST TIME")
		_wear(StoryMode.PASS_KM)
		dialogue.set_caption("")
		result["connected"] = run["time"]
	if b.has("purse"):
		# Night 1: beat Ghost in any one sector.
		var any := false
		for tr in times:
			any = any or float(tr[1]) < _ghost.sector_time(int(tr[0]))
		_pay_out(b, 1 if any else 99)
	StoryMode.results[b["id"]] = result
	StoryMode.save()
	_hold(true)
	if b.has("after_cards"):
		await _examine(b, b["after_cards"])
	await _lines(b, after_key(b, float(result.get("connected", INF)), _target(b), _ghost.time))


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
	_show_drive_hud()
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
	await _coast(2.0)
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
		_pay_in(b)
		_hold(false)
		time_attack.records = false
		time_attack.reference = _target(b)
		time_attack.ghost_override = _ghost.frames
		time_attack.best_label = "GHOST TIME"
		time_attack.ghost_opacity = 0.6
		var begin := func(): recorder.begin()
		time_attack.started.connect(begin, CONNECT_ONE_SHOT)
		time_attack.restart(false)
	var cues := [[PASS_TRACK.start_distance + 330.0, "JOLO", "Feels different here."], [PASS_TRACK.start_distance + 365.0, "JOLO", "It's wet past the sign."],
		[entry - 230.0, "JOLO", "Pang."], [entry - 150.0, "JOLO", "Pang, it's wet. It's wet."]]
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
				dialogue.subtitle("JOLO", "Okay. Okay.", 2.0)
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
	drive_track = t
	# The recce (S34) has no ghost: the road as it is today.
	if b.get("ghost", true):
		_ghost_car = _ghost_car if _ghost_car else (_make_ghost_car() if _ghost.valid() else null)
	# Lines said on the way, at metres from 8A's entry: [offset, who, text].
	var cues: Array = b.get("cues", []).duplicate()
	var index := t.nearest_index(session.car.global_position)
	var ghost_t := -1.0
	var ghost_life := 0.0
	while is_inside_tree():
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		truck.step(dt, get_tree().get_nodes_in_group(&"cars"))
		index = t.nearest_index(session.car.global_position, index)
		var d := index * t.spacing
		while not cues.is_empty() and d >= entry + float(cues[0][0]):
			var c: Array = cues.pop_front()
			dialogue.subtitle(c[1], c[2], 3.0)
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
	await _coast(2.5)
	_hold(true)
	truck.queue_free()
	await _lines(b, "after")


# --- Free roam ---------------------------------------------------------------------------------


## Where the garage is: the talyer's bays (hub x, z rect), and how close counts as pulled up.
const BAYS := Rect2(8.5, 151, 31, 16.5)
const PULL_UP := 7.5
const BOARD_REACH := 6.0


## The barangay between scenes: drive anywhere; pull up at Ruel's for the garage, beside a regular
## at Bahandi Fuels to race them, at Kapitan's board for everything open; drive into the NEXT place
## and press E to carry on the story.
func _roam(b: Dictionary) -> void:
	await _settle(b)
	if not StoryMode.once.has("seen:" + b["id"]):
		await _lines(b, "before")
		StoryMode.once["seen:" + b["id"]] = true
	var parked := _park_regulars(b)
	var board_prop := _board_prop() if not StoryBoard.events(b).is_empty() else null
	drive_track = null
	var left := ""
	# Probes play roams on their own; PANG_ROAM=1 leaves one open (screenshots of the barangay).
	if StoryDialogue.auto_advance > 0.0 and not OS.has_environment("PANG_ROAM"):
		await _auto_roam(b)
	else:
		left = await _roam_loop(b, parked)
	if left == "side":
		# Up the mountain for a board event: this scene is on its way out, the beat stays put.
		while is_inside_tree():
			await get_tree().process_frame
		return
	for car in parked:
		car.queue_free()
	if board_prop:
		board_prop.queue_free()
	_prompt.text = ""
	_money.text = ""
	_objective.text = ""
	StoryMode.roam_from = ""
	var next: String = b["next"]
	var i := StoryMode.beat + 1
	var nb: Dictionary = StoryScript.BEATS[i] if i < StoryScript.BEATS.size() else {}
	if nb.get("spot", "") == next and SPOT_VIEWS.has(next):
		await _ease_into(next)
	_hold(true)


## Returns "next" when the player carries on, "side" when a board event took them up the mountain.
func _roam_loop(b: Dictionary, parked: Array) -> String:
	var next: Dictionary = HubLayout.PLACES[b["next"]]
	var area: Rect2 = next["area"]
	_hold(false)
	while is_inside_tree():
		await get_tree().process_frame
		var p := session.car.global_position
		var at := Vector2(p.x, -p.z)
		var to := area.get_center() - at
		if _toast_left <= 0.0:
			_objective.text = "▶  NEXT:  %s   %d m" % [b.get("prompt", next["name"]), int(to.length())]
		_toast_left -= get_process_delta_time()
		_money.text = "₱%s     RUEL  ₱%s" % [StoryGarage._pesos(StoryMode.wallet()), StoryGarage._pesos(StoryMode.owed())]
		var action := _roam_action(b, parked, at)
		_prompt.text = action.get("text", "")
		if action.is_empty() or not Input.is_action_just_pressed("interact"):
			continue
		_prompt.text = ""
		match action["do"]:
			"next":
				return "next"
			"garage":
				await _open_garage("shop")
				_hold(false)
			"board":
				_hold(true)
				var picked := await garage.open_board(StoryBoard.events(b))
				_hold(false)
				if not picked.is_empty():
					if await _run_event(b, picked):
						return "side"
			"race":
				if await _run_event(b, action["event"]):
					return "side"
		session.camera.current = true
	return "next"


## What E does here, if anything: { text, do, event }.
func _roam_action(b: Dictionary, parked: Array, at: Vector2) -> Dictionary:
	if session.car.linear_velocity.length() > 3.0:
		return {}
	var area: Rect2 = HubLayout.PLACES[b["next"]]["area"]
	if area.has_point(at):
		return { "text": "E   CONTINUE  ·  %s" % b.get("prompt", HubLayout.PLACES[b["next"]]["name"]), "do": "next" }
	var events := StoryBoard.events(b)
	for car in parked:
		if car.global_position.distance_to(session.car.global_position) < PULL_UP:
			var k: int = car.get_meta("regular")
			for e in events:
				if e["kind"] == "sprint" and int(e["regular"]) == k:
					var r: Dictionary = StoryBoard.REGULARS[k]
					if e["done"]:
						return { "text": "%s  ·  \"Already took your money tonight.\"" % r["who"][0], "do": "none" }
					return { "text": "E   RACE %s   ·   IN ₱%s   ·   WIN ₱%s" % [r["who"][0], StoryGarage._pesos(int(e["entry"])),
						StoryGarage._pesos(int(e["purse"][0]))], "do": "race", "event": e }
	if not events.is_empty() and at.distance_to(StoryBoard.BOARD_AT) < BOARD_REACH:
		return { "text": "E   KAPITAN'S BOARD", "do": "board" }
	if BAYS.has_point(at):
		return { "text": "E   RUEL'S GARAGE  ·  PARTS, TUNING, THE BILL", "do": "garage" }
	return {}


## The regulars who race this roam, parked nose-out on the forecourt.
func _park_regulars(b: Dictionary) -> Array:
	var out := []
	if hub == null:
		return out
	for e in StoryBoard.events(b):
		if e["kind"] != "sprint":
			continue
		var r: Dictionary = StoryBoard.REGULARS[int(e["regular"])]
		var car := CarRoster.get_car(r["who"][1])
		var at: Vector3 = r["park"]
		var body: CarBody = hub.spawn_parked(car["model"], car["preset"], Color(r["who"][2]), HubLayout.pos(at.x, at.y, 0.3), HubLayout.yaw(at.z))
		body.set_meta("regular", int(e["regular"]))
		out.append(body)
	return out


## Kapitan's board by the shop door: a whiteboard on two legs.
func _board_prop() -> Node3D:
	var prop := Node3D.new()
	prop.position = HubLayout.pos(StoryBoard.BOARD_AT.x, StoryBoard.BOARD_AT.y + 1.5)
	var face := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 1.3, 0.06)
	face.mesh = box
	face.position.y = 1.5
	face.material_override = MangaArt.world_preset("board")
	prop.add_child(face)
	for x in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 1.0
		leg.mesh = cyl
		leg.position = Vector3(x, 0.5, 0)
		leg.material_override = MangaArt.world_preset("post")
		prop.add_child(leg)
	var title := Label3D.new()
	title.text = "KAPITAN'S BOARD"
	title.font_size = 64
	title.pixel_size = 0.004
	title.modulate = MangaType.INK
	title.outline_size = 0
	title.position = Vector3(0, 1.9, 0.05)
	prop.add_child(title)
	add_child(prop)
	return prop


## Run an event picked in free roam. Sprints race here, on the loop; mountain events go up to
## Pass 1 and come back (returns true: the roam restarts from the gas station after).
func _run_event(b: Dictionary, e: Dictionary) -> bool:
	if not StoryMode.pay_entry(int(e["entry"]), false):
		_toast("ENTRY'S ₱%s" % StoryGarage._pesos(int(e["entry"])))
		return false
	if StoryMode.timeline() == "memory":
		StoryMode.once[StoryBoard.once_key(b["id"], e["id"])] = true
	if e["kind"] != "sprint":
		StoryMode.side = e.duplicate(true)
		StoryMode.side["stage"] = "pass"
		StoryMode.save()
		await dialogue.fade(true, 0.45)
		StoryMode.run_side(get_tree())
		return true
	var r: Dictionary = StoryBoard.REGULARS[int(e["regular"])]
	var name: String = r["who"][0]
	_hold(true)
	await dialogue.play([[name, r["hello"]]])
	var race := { "id": "sprint", "course": "loop", "laps": 1 }
	var place := await _race_core(race, _field(e["field"]), false)
	var won := StoryBoard.payout(e["purse"], place, "sprint")
	if won > 0:
		StoryMode.earn(won)
		StoryMode.set_flag("won:" + name)
		_toast("WON  ₱%s   ·   WALLET  ₱%s" % [StoryGarage._pesos(won), StoryGarage._pesos(StoryMode.wallet())])
	var lines := [[name, r["won"] if place == 1 else r["lost"]]]
	if place == 1 and r.has("reply_won"):
		lines.append(["PANG", r["reply_won"]])
	await dialogue.play(lines)
	StoryMode.save()
	_hold(false)
	return false


## Probes: run the first open sprint (if the wallet covers it), buy a part, carry on.
func _auto_roam(b: Dictionary) -> void:
	_auto_shop()
	for e in StoryBoard.events(b):
		if e["kind"] == "sprint" and not e["done"] and StoryMode.wallet() >= int(e["entry"]) and not StoryMode.once.has("probe:" + b["id"]):
			StoryMode.once["probe:" + b["id"]] = true
			await _run_event(b, e)
			break
	var c: Vector2 = (HubLayout.PLACES[b["next"]]["area"] as Rect2).get_center()
	await _place({ "position": HubLayout.pos(c.x, c.y, 0.3), "heading": session.car.rotation.y })


## A mountain event from the board, on the pass stage: the clock (one timed run, pay bands) or
## the downhill (a three-car race).
func _side_event(e: Dictionary) -> void:
	MangaArt.apply_night(0.15)
	weather.rain = 0.0
	weather.wet = 0.0
	_fit_car()
	await _place(PASS_TRACK.pose_at(PASS_TRACK.start_distance - 8.0))
	dialogue.set_caption(e["title"])
	await dialogue.fade(false, 0.5)
	drive_track = PASS_TRACK
	if e["kind"] == "clock":
		var bands: Array = e["bands"]
		var run := await _timed_run({ "time": float(bands[0][0]), "splits": PackedFloat64Array() }, PackedFloat32Array(), "KAPITAN'S GOLD")
		_wear(StoryMode.PASS_KM)
		var pay := StoryBoard.clock_pay(float(run["time"]), bands)
		StoryMode.earn(pay)
		dialogue.set_caption("")
		await dialogue.play([["KAPITAN", ("%s. Here. ₱%s." % [TimeAttackRun.format_time(run["time"]), StoryGarage._pesos(pay)]) if pay > 0
			else "%s. Stopwatch says no." % TimeAttackRun.format_time(run["time"])]])
	else:
		var place := await _race_core({ "id": "downhill", "course": "pass" }, _field(e["field"]), false)
		var pay := StoryBoard.payout(e["purse"], place)
		StoryMode.earn(pay)
		dialogue.set_caption("")
		await dialogue.play([["KAPITAN", "P%d. ₱%s. Same time next week." % [place, StoryGarage._pesos(pay)]]])
	StoryMode.save()


# --- Test drives, the qualifiers and the final -------------------------------------------------


## A drive with no clock: the shakedown on the loop, or the lights test on Pass 1 at night.
func _test(b: Dictionary) -> void:
	if b.get("kind", "") == "lights":
		await _lights_test(b)
		return
	await _settle(b)
	await _lines(b, "before")
	# Two laps from the talyer's stretch of the loop at town speed: the first pulls left.
	var t := HubLayout.loop_track(4)
	var lap := t.length() / 4.0
	var start := lap + t.nearest_index(HubLayout.pos(30, 140)) * t.spacing
	drive_track = t
	await _place(t.pose_at(start, 1.6))
	for k in 2:
		var pull := -0.14 if k == 0 else 0.0
		_hold(false)
		session.set_clean_feed(true)
		session.input_filter = func(i: VehicleTypes.DriverInput) -> VehicleTypes.DriverInput:
			i.steer = clampf(i.steer + pull, -1.0, 1.0)
			if session.car.linear_velocity.length() > HubLayout.CRUISE_SPEED * 1.3:
				i.throttle = 0.0
			return i
		var index := t.nearest_index(session.car.global_position, int(start / t.spacing))
		while is_inside_tree():
			await get_tree().physics_frame
			index = t.nearest_index(session.car.global_position, index)
			if index * t.spacing >= start + lap * (k + 1) - 6.0:
				break
		await _coast(1.6)
		_hold(true)
		await _lines(b, "between" if k == 0 else "after_lap")
	_wear(2.0 * StoryMode.LOOP_KM)
	await _lines(b, "after")


## R16: Nico on the lower road, Pang on the upper, the night run's numbers; recorded, then laid
## over the crash run's bearing to the lights.
func _lights_test(b: Dictionary) -> void:
	var t := PASS_TRACK
	MangaArt.apply_night(1.0)
	weather.rain = 0.0
	weather.wet = 0.0
	await _settle(b)
	await _place(t.pose_at(t.start_distance - 8.0))
	await _lines(b, "before")
	time_attack.free_drive()
	if music:
		music.stop_music()
	drive_track = t
	_hold(false)
	session.set_clean_feed(true)
	recorder.begin()
	var entry := StoryCourse.fatal_entry()
	var cues := [[entry - StoryCourse.LIGHTS_FROM, "NICO", "I'm below you."], [entry - 90.0, "NICO", "Still below you."],
		[entry - 20.0, "NICO", "Still below you. Sixty metres down."]]
	var index := t.nearest_index(session.car.global_position)
	var lights: HeadlightsRig = null
	while is_inside_tree():
		await get_tree().physics_frame
		index = t.nearest_index(session.car.global_position, index)
		var d := index * t.spacing
		while not cues.is_empty() and d >= float(cues[0][0]):
			var c: Array = cues.pop_front()
			dialogue.subtitle(c[1], c[2], 3.0)
		if lights == null and d >= entry - StoryCourse.LIGHTS_FROM:
			lights = HeadlightsRig.new()
			lights.track = t
			add_child(lights)
			dialogue.sfx("pulse")
		if d >= entry + 40.0 or d >= t.finish_distance - 12.0:
			break
	StoryMode.record["lights_test"] = StoryMode.pack(recorder.stop())
	await _coast(2.5)
	_hold(true)
	if lights:
		lights.queue_free()
	_wear(StoryMode.PASS_KM * 0.7)
	StoryMode.save()
	if b.has("after_cards"):
		await _examine(b, b["after_cards"])
	await _lines(b, "after")


## A qualifying run: one timed run, the clock only, no ghost. The better of the two sets the grid
## for the final against Nico's (top) qualifying time; `garage` opens Ruel's toolbox after.
func _trial(b: Dictionary) -> void:
	await _settle(b)
	await _lines(b, "before")
	_pay_in(b)
	drive_track = PASS_TRACK
	var run := await _timed_run({}, PackedFloat32Array(), "BEST")
	_wear(StoryMode.PASS_KM)
	StoryMode.results[b["id"]] = { "time": run["time"] }
	var best := INF
	for id in ["s33b1", "s33b2"]:
		best = minf(best, float(StoryMode.results.get(id, {}).get("time", INF)))
	var nico := nico_qualifying()
	StoryMode.results["r18"] = { "best": best, "nico": nico, "grid": 1 if best < nico else 2 }
	StoryMode.save()
	_hold(true)
	await dialogue.play([["RUEL", "%s. Official clock says the same. Nico's %s." % [TimeAttackRun.format_time(run["time"]), TimeAttackRun.format_time(nico)]]])
	if b.get("garage", false):
		await _open_garage("tune")
	await _lines(b, "after")


## Nico's best qualifying run: the line study's cut, give or take (he has driven it more than anyone).
func nico_qualifying() -> float:
	return _ghost.time * 1.01 if _ghost.valid() else 80.0


## R19: Pang against Nico on the closed road. From 300 m before 8A the Ghost Line comes up from
## behind at its dry pace wanting the inside, through the damp patch; hold wide with a lift and
## it passes through; follow it and the patch takes the grip. No music through 8A. The result is
## a photograph: the place, no time.
const PATCH_GRIP := 0.55
const PATCH_GRIP_RAIN := 0.75


func _final(b: Dictionary) -> void:
	await _settle(b)
	MangaArt.apply_night(0.1)
	weather.rain = 0.0
	weather.wet = 0.0
	await _lines(b, "before")
	var br := CarParts.rating(StoryMode.car())
	var nico := StoryScript.NICO.duplicate()
	# Build-matched, not rubber-banded: Nico's pace follows the car Pang brought.
	nico[3] = clampf(0.92 + 0.008 * br, 0.92, 0.99)
	var grid := int(StoryMode.results.get("r18", {}).get("grid", 2))
	dialogue.set_caption("THE LAST LINE  ·  GRID P%d" % grid)
	var st := { "patch": false, "flash": false }
	_final_watch(st)
	var place := await _race_core(b, _field([nico]), false)
	session.car.surface_scale = 1.0
	dialogue.set_caption("")
	StoryMode.results["s34a"] = { "place": place, "entered_patch": st["patch"] }
	StoryMode.save()
	# The result card: the car at the finish, frozen, and where it came. No time.
	await dialogue.comic([[{ "art": "snap", "cap": "THE LAST LINE  ·  %s" % ("1ST" if place == 1 else "2ND") }]], "fade")
	await _lines(b, "chased" if st["patch"] else "lifted")
	await _lines(b, "after")


## During the final: the damp patch under the player's car (inside of 8A), the ghost from 300 m
## out, the music gone through the bend.
func _final_watch(st: Dictionary) -> void:
	var t := PASS_TRACK
	var entry := StoryCourse.fatal_entry()
	var exit := StoryCourse.fatal_exit()
	_ghost_car = _ghost_car if _ghost_car else (_make_ghost_car() if _ghost.valid() else null)
	var ghost_t := -1.0
	var life := 0.0
	var index := t.nearest_index(session.car.global_position)
	var quiet := false
	var started := false
	var rain_set := CarParts.has(StoryMode.car(), "rain_set")
	while is_inside_tree() and StoryMode.active:
		await get_tree().physics_frame
		if vs_battle == null or not vs_battle.active:
			if started:
				break
			continue
		started = true
		var dt := get_physics_process_delta_time()
		var p := session.car.global_position
		index = t.nearest_index(p, index)
		var d := index * t.spacing
		var lateral := t.lateral_offset(p, index)
		# Inside of the right-hand hairpin: the right half of the road, from the entry to the exit.
		var in_patch := d >= entry - 4.0 and d <= exit + 4.0 and lateral > 0.6
		session.car.surface_scale = (PATCH_GRIP_RAIN if rain_set else PATCH_GRIP) if in_patch else 1.0
		if in_patch:
			st["patch"] = true
		if not quiet and d >= entry - 300.0:
			quiet = true
			if music:
				music.stop_music(1.0)
		if _ghost_car and ghost_t < 0.0 and d >= entry - 300.0:
			# It starts behind and closes: the cut's dry pace beats anything on today's road.
			ghost_t = StoryCourse.ghost_time_at(_ghost, d - 25.0)
		if _ghost_car and ghost_t >= 0.0 and life < 14.0:
			ghost_t += dt
			life += dt
			_ghost_car.opacity = clampf(minf(life * 0.6, (14.0 - life) * 0.3), 0.0, 0.55)
			var pose := _ghost.pose(ghost_t)
			_ghost_car.show_pose(pose)
			if not st["flash"] and not pose.is_empty() and (pose["position"] as Vector3).distance_to(p) < 2.2:
				st["flash"] = true
				dialogue.flash_white(0.3)
		elif _ghost_car:
			_ghost_car.show_pose({})
	session.car.surface_scale = 1.0
	if _ghost_car:
		_ghost_car.show_pose({})


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
	c["lights_crash"] = StoryCourse.lights_bearings(c["crash"], PASS_TRACK)
	c["lights_test"] = StoryCourse.lights_bearings(StoryMode.unpack(StoryMode.record.get("lights_test", "")), PASS_TRACK)
	c["camera_cut"] = float(StoryMode.record.get("camera_cut", -1.0))
	if _ghost.valid():
		c["board"] = _board_rows()
		c["notes"] = _notes_rows()
		c["trials"] = _trial_rows()
	return c


## The challenge board, Dante's numbers: the posted time with the sectors scaled to it. Drivers who
## matched a sector, nobody who matched the sum.
func _board_rows() -> Array:
	var rows := []
	var gs := []
	var posted := target_for(_ghost, true)
	var psp: PackedFloat64Array = posted["splits"]
	for k in 4:
		gs.append(psp[k] - (psp[k - 1] if k > 0 else 0.0))
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
	ghost_row.append(TimeAttackRun.format_time(posted["time"]))
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
	rows.append(["GHOST TIME AS POSTED", TimeAttackRun.format_time(StoryMode.posted_time(_ghost.time))])
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
