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
const SCRIPT_VERSION := 2
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


static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


static func load_save() -> void:
	beat = 0
	record = {}
	results = {}
	reached = 0
	completed = false
	stale = false
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


static func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({ "script": SCRIPT_VERSION, "beat": beat, "record": record, "results": results,
		"reached": reached, "completed": completed, "date": Time.get_datetime_string_from_system() }))
	f.close()


static func start_new(tree: SceneTree) -> void:
	load_save()
	beat = 0
	record = {}
	results = {}
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
