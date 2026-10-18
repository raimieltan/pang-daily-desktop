class_name StoryMode
extends RefCounted
## Story mode ("The Ghost Line", docs/story/STORY_MODE.md): where the player is in StoryScript.BEATS,
## what the story has recorded about their driving, and the hand-off between the scenes a beat
## needs (Pass 1, the barangay, a room, or a paper panel). Saved locally after every beat.
##
## The record is the point: the practice passes the player drives in "A Line Study" become the
## Ghost Line they chase, the crash run becomes the logger they read, the sector trials become the
## comparison Nico publishes. Nothing in the evidence is canned.

## Where progress is saved (probes point it elsewhere).
static var save_path := "user://story.json"
## The beat order the save's position belongs to: a save from another order starts over (its
## recorded passes meant something else there).
const SCRIPT_VERSION := 3
const PASS_SCENE := "res://scenes/touge.tscn"
const HUB_SCENE := "res://scenes/hub.tscn"
const PANEL_SCENE := "res://scenes/story_panel.tscn"
const ROOM_SCENE := "res://scenes/story_room.tscn"
## Pang's car: the EG hatch in paint gone between blue and grey (manuscript, chapter one).
const CAR_ID := "eg_hatch"
const CAR_PAINT := Color(0.46, 0.52, 0.58)

## True while a scene is running the story (its StoryDirector drives it).
static var active := false
## Index into StoryScript.BEATS of the beat to run next.
static var beat := 0
## Telemetry the story has recorded (StoryRecorder frames, base64 PackedFloat32Array):
## "passes": [{ "label", "frames", "splits", "time" }], "crash": frames, "trials": {...}.
static var record := {}
## Results of the story's races, by beat id: { "place": int, "time": float, ... }.
static var results := {}
## The furthest beat ever reached (the story page lists the acts up to it), and whether the
## story has been played to the end.
static var reached := 0
static var completed := false
## True after load_save found a save from another script order and set it aside (the menu says so).
static var stale := false

## Progression (docs/story/STORY_MODE.md "Money, parts and free roam"), kept per timeline:
## "memory" (the months before, Dante's money) and "present" (the rebuild, Ruel's way).
## cars: { timeline: CarParts build + "setup" (CarSetup steps) }; wallets: { timeline: pesos };
## ledgers: { timeline: [[what, pesos], ...] } (Ruel's clipboard; payments are negative);
## commitments: [[what, pesos], ...] (Jolo's, shown beside the memory ledger, never payable);
## rep: { flag: true } ("list" = Dante's list, "won:NAME"); once: { event key: true } (memory
## events run); snapshot: the memory car as it was at the line study (s06).
static var cars := {}
static var wallets := {}
static var ledgers := {}
static var commitments := []
static var rep := {}
static var once := {}
static var snapshot := {}
## A mountain event picked off Kapitan's board mid-roam (StoryBoard event + "stage"): the pass
## scene runs it, then the roam beat starts again from `roam_from` (a HubLayout.PLACES key).
static var side := {}
static var roam_from := ""


static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


static func load_save() -> void:
	beat = 0
	record = {}
	results = {}
	reached = 0
	completed = false
	stale = false
	reset_progress()
	if not has_save():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	stale = not (data is Dictionary and int(data.get("script", 0)) == SCRIPT_VERSION)
	if not stale:
		beat = int(data.get("beat", 0))
		record = data.get("record", {})
		results = data.get("results", {})
		reached = int(data.get("reached", beat))
		completed = bool(data.get("completed", false))
		var p: Dictionary = data.get("progress", {})
		if p.get("cars") is Dictionary and p["cars"].has("memory") and p["cars"].has("present"):
			cars = p["cars"]
		if p.get("wallets") is Dictionary and not p["wallets"].is_empty():
			wallets = p["wallets"]
		if p.get("ledgers") is Dictionary and not p["ledgers"].is_empty():
			ledgers = p["ledgers"]
		rep = p.get("rep", {}) if p.get("rep") is Dictionary else {}
		once = p.get("once", {}) if p.get("once") is Dictionary else {}
		snapshot = p.get("snapshot", {}) if p.get("snapshot") is Dictionary else {}
		commitments = p.get("commitments", []) if p.get("commitments") is Array else []


static func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({ "script": SCRIPT_VERSION, "beat": beat, "record": record, "results": results,
		"reached": reached, "completed": completed, "date": Time.get_datetime_string_from_system(),
		"progress": { "cars": cars, "wallets": wallets, "ledgers": ledgers, "commitments": commitments,
			"rep": rep, "once": once, "snapshot": snapshot } }))
	f.close()


static func start_new(tree: SceneTree) -> void:
	load_save()
	beat = 0
	record = {}
	results = {}
	reset_progress()
	save()
	goto(tree, 0)


static func resume(tree: SceneTree) -> void:
	load_save()
	goto(tree, clampi(beat, 0, StoryScript.BEATS.size() - 1))


## Run beat `index`: in the current scene if it is the beat's stage, else via a scene change.
static func goto(tree: SceneTree, index: int) -> void:
	active = true
	beat = index
	save()
	tree.paused = false
	tree.change_scene_to_file(scene_for(StoryScript.BEATS[index]))


static func scene_for(b: Dictionary) -> String:
	match b.get("stage", "panel"):
		"pass":
			return PASS_SCENE
		"hub":
			return HUB_SCENE
		"room":
			return ROOM_SCENE
	return PANEL_SCENE


## Up to Pass 1 for the board's mountain event (StoryMode.side), without leaving the roam beat.
static func run_side(tree: SceneTree) -> void:
	active = true
	save()
	tree.paused = false
	tree.change_scene_to_file(PASS_SCENE)


## Replay from the first beat of an act already reached (the recorded passes stay).
static func play_from(tree: SceneTree, index: int) -> void:
	StoryBridge.node().release_all(0.3)
	load_save()
	goto(tree, clampi(index, 0, reached))


## The end: the story is complete; the next CONTINUE starts it again (records kept).
static func finish(tree: SceneTree) -> void:
	completed = true
	beat = 0
	save()
	quit_to_title(tree)


## Leave the story for the title screen (progress stays saved).
static func quit_to_title(tree: SceneTree) -> void:
	active = false
	side = {}
	roam_from = ""
	StoryBridge.node().release_all(0.3)
	tree.paused = false
	tree.change_scene_to_file(PASS_SCENE)


static func current() -> Dictionary:
	return StoryScript.BEATS[clampi(beat, 0, StoryScript.BEATS.size() - 1)]


# --- Recorded driving -------------------------------------------------------------------------


static func pack(frames: PackedFloat32Array) -> String:
	return Marshalls.raw_to_base64(frames.to_byte_array())


static func unpack(text: String) -> PackedFloat32Array:
	return Marshalls.base64_to_raw(text).to_float32_array() if text != "" else PackedFloat32Array()


## The line study's floor: three passes baked from a quick driver (tools/bake_passes.gd), one per
## slot. Pang was quick that week whatever the player does, so a recorded pass slower than the
## baked one in its slot takes the baked driving under its own label: the Ghost Line is never a
## lap anyone could beat by driving the study badly.
const BAKED_PATH := "res://game/story/baked_passes.json"
static var baked: Array = []
static var _baked_loaded := false
## Off while baking the floor itself (tools/bake_passes.gd): the driven passes are kept as driven.
static var use_floor := true


static func baked_passes() -> Array:
	if not _baked_loaded and baked.is_empty():
		_baked_loaded = true
		if FileAccess.file_exists(BAKED_PATH):
			var data = JSON.parse_string(FileAccess.get_file_as_string(BAKED_PATH))
			if data is Array:
				baked = data
	return baked


static func add_pass(label: String, frames: PackedFloat32Array, splits: PackedFloat64Array, time: float) -> void:
	var passes: Array = record.get("passes", [])
	var entry := { "label": label, "frames": pack(frames), "splits": Array(splits), "time": time }
	var slot := passes.size()
	var floor := baked_passes() if use_floor else []
	if slot < floor.size() and float(floor[slot]["time"]) < time:
		entry = { "label": label, "frames": floor[slot]["frames"], "splits": Array(floor[slot]["splits"]),
			"time": float(floor[slot]["time"]) }
	passes.append(entry)
	record["passes"] = passes
	record.erase("ghost")


## Dante's number. "Dante took something off it": the GHOST TIME he posted is the cut's time less
## POSTED_CUT, so the car in the clip arrives after the clock says it did. Beat it in public and
## he reposts a time under yours ("Ghost responded"); the record keeps that.
const POSTED_CUT := 0.03
const REPOST_MARGIN := 0.3


static func posted_time(cut: float) -> float:
	return float(record["posted"]) if record.has("posted") else cut * (1.0 - POSTED_CUT)


static func repost(run_time: float) -> void:
	record["posted"] = floorf((run_time - REPOST_MARGIN) * 100.0) / 100.0


## The Ghost Line, built (and cached) from the practice passes: GhostLine.composite().
static func ghost_line() -> GhostLine:
	var passes: Array = record.get("passes", [])
	var sources: Array = []
	for p in passes:
		sources.append({ "label": p["label"], "frames": unpack(p["frames"]),
			"splits": PackedFloat64Array(p["splits"]), "time": float(p["time"]) })
	return GhostLine.composite(sources)


# --- Money, parts and the two cars ------------------------------------------------------------

## Where each timeline starts: the faded EG and R1's entry money; the repaired wreck and a bill.
const START_WALLET := { "memory": 1200, "present": 0 }
## Three seasons on them (Nico can see it), not yet dead: R1 has to be winnable on them. The wreck came back from Ruel on part-worn street tires.
const START_WEAR := { "memory": { "front": 0.6, "rear": 0.6 }, "present": { "front": 0.85, "rear": 0.85 } }
const START_BILL := { "memory": ["SHOP BILL", 8500], "present": ["REPAIRS (THE CRASH)", 38000] }
## Grand total of a timeline's nominal driving is charged as wear: a Pass 1 run, a loop lap (km).
const PASS_KM := 1.4
const LOOP_KM := 0.75


static func reset_progress() -> void:
	cars = { "memory": _start_car(START_WEAR["memory"]), "present": _start_car(START_WEAR["present"]) }
	wallets = START_WALLET.duplicate()
	ledgers = { "memory": [START_BILL["memory"].duplicate()], "present": [START_BILL["present"].duplicate()] }
	commitments = []
	rep = {}
	once = {}
	snapshot = {}


static func _start_car(wear := { "front": 1.0, "rear": 1.0 }) -> Dictionary:
	var c := CarParts.new_build()
	c["wear"] = wear.duplicate()
	c["setup"] = {}
	return c


## The timeline of beat `index`: inside a memory, or the cold open before Act I, is "memory".
static func timeline(index := -1) -> String:
	var i := beat if index < 0 else index
	if StoryScript.memory_of(i) != "" or i < StoryScript.index_of("a1_card"):
		return "memory"
	return "present"


## The car a beat drives: the timeline's build, or (`snapshot`) the line-study car, so the
## evidence compares like with like.
static func car(index := -1) -> Dictionary:
	var i := beat if index < 0 else index
	var b: Dictionary = StoryScript.BEATS[clampi(i, 0, StoryScript.BEATS.size() - 1)]
	if b.get("snapshot", "") != "" and not snapshot.is_empty():
		return snapshot
	var tl := timeline(i)
	if not cars.has(tl):
		cars[tl] = _start_car()
	return cars[tl]


## The line-study build, taken when the line study starts (a copy; the memory car carries on).
static func take_snapshot() -> void:
	snapshot = cars["memory"].duplicate(true)


static func wallet(tl := "") -> int:
	return int(wallets.get(tl if tl != "" else timeline(), 0))


static func earn(pesos: int, tl := "") -> void:
	var t := tl if tl != "" else timeline()
	wallets[t] = wallet(t) + pesos


## Spend from the wallet; false (and nothing spent) when it can't cover it.
static func spend(pesos: int, tl := "") -> bool:
	var t := tl if tl != "" else timeline()
	if wallet(t) < pesos:
		return false
	wallets[t] = wallet(t) - pesos
	return true


static func owed(tl := "") -> int:
	var total := 0
	for entry in ledgers.get(tl if tl != "" else timeline(), []):
		total += int(entry[1])
	return total


## Something written on Ruel's clipboard (a part fitted at cost, an entry he covered).
static func bill(what: String, pesos: int, tl := "") -> void:
	var t := tl if tl != "" else timeline()
	var lines: Array = ledgers.get(t, [])
	lines.append([what, pesos])
	ledgers[t] = lines


## Pay toward the bill from the wallet (never more than is owed). Returns what was paid.
static func pay_bill(pesos: int, tl := "") -> int:
	var t := tl if tl != "" else timeline()
	var amount := mini(pesos, mini(owed(t), wallet(t)))
	if amount <= 0:
		return 0
	spend(amount, t)
	bill("PAID", -amount, t)
	return amount


static func commitments_total() -> int:
	var total := 0
	for entry in commitments:
		total += int(entry[1])
	return total


## An entry fee. Paid from the wallet when it can be; a required entry it can't cover is covered
## anyway and written down (memory: Jolo's commitments; present: Ruel's bill), so the story never
## stops for money. Returns false only for an optional entry the player can't afford.
static func pay_entry(pesos: int, required: bool, what := "ENTRY") -> bool:
	if pesos <= 0 or spend(pesos):
		return true
	if not required:
		return false
	if timeline() == "memory":
		commitments.append(["%s (JOLO COVERED IT)" % what, pesos])
	else:
		bill("%s (RUEL COVERED IT)" % what, pesos)
	return true


## Wear for `km` of driving on the beat's car (the snapshot wears too: it is a copy for the trial).
static func drive(km: float) -> void:
	CarParts.charge(car(), km)


static func flag(name: String) -> bool:
	return rep.get(name, false)


static func set_flag(name: String, on := true) -> void:
	rep[name] = on
