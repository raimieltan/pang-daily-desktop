extends SceneTree
## Story trailer capture. The game never loads this: `trailer/story_capture.sh <beat> [flags]` writes
## a temporary override.cfg (16:9 frame, trailer-only user dir) and runs
##   godot --path . --write-movie trailer/out/story/<name>.avi --fixed-fps 60 -s res://trailer/story_capture.gd -- --beat=<id>
## It starts "The Ghost Line" at that beat on the trailer's probe save (the passes, the cut and the
## crash log are the ones `--probe-story` recorded), lets the story play with lines auto-advancing
## and the AI driving every drive beat, and quits after --length seconds. Next to the AVI it writes
## <name>.events.json: beat changes, every line as it lands (speaker, text, caption, stamp), so the
## edit can cut to the exact frame a line appears.
##
## Flags (after `--`):
##   --beat=<id>         the StoryScript beat to start at
##   --length=<s>        seconds to record (default 20)
##   --name=<name>       output base name (default the beat id)
##   --out=<dir>         where events go (default res://trailer/out/story)
##   --advance=<s>       how long a typed line holds before the next (default 2.2)
##   --clean             hide the story's 2D layer (dialogue, captions, fades) and the HUD: clean plates
##   --cams=<t:shot,…>   override the camera at these times: chase far hood bumper (game views)

const GAME_SHOTS := { "chase": ChaseCamera.Mode.CHASE, "far": ChaseCamera.Mode.FAR,
	"hood": ChaseCamera.Mode.HOOD, "bumper": ChaseCamera.Mode.BUMPER }

var beat_id := "s00"
var length := 20.0
var out_name := ""
var out_dir := "res://trailer/out/story"
var advance := 2.2
var clean := false
var cams: Array = []          # [[t, shot], …] sorted by t

var t := 0.0
var _beat := -1
var _scene: Node
var _dialogue: StoryDialogue
var _driver: AiDriver
var _last_pos := Vector3.ZERO
var _seen := {}
var _events := { "beats": [], "lines": [], "marks": [] }
var _done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--beat="): beat_id = a.get_slice("=", 1)
		elif a.begins_with("--length="): length = float(a.get_slice("=", 1))
		elif a.begins_with("--name="): out_name = a.get_slice("=", 1)
		elif a.begins_with("--out="): out_dir = a.get_slice("=", 1)
		elif a.begins_with("--advance="): advance = float(a.get_slice("=", 1))
		elif a == "--clean": clean = true
		elif a.begins_with("--cams="):
			for c in a.get_slice("=", 1).split(","):
				cams.append([float(c.get_slice(":", 0)), c.get_slice(":", 1)])
	if out_name == "":
		out_name = beat_id + ("_clean" if clean else "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	StoryMode.save_path = "user://story_probe.json"
	StoryDialogue.auto_advance = advance
	StoryMode.load_save()
	var i := StoryScript.index_of(beat_id)
	if i < 0:
		push_error("no beat " + beat_id)
		quit(1)
		return
	StoryMode.goto.call_deferred(self, i)


func _process(delta: float) -> bool:
	t += delta
	# Full-res 3D for footage; the trailer lays its own music over the game's ambience and engine.
	root.scaling_3d_scale = 1.0
	var music := AudioServer.get_bus_index("Music")
	if music >= 0:
		AudioServer.set_bus_mute(music, true)
	if current_scene != _scene:
		_scene = current_scene
		_dialogue = null
		_driver = null
		_seen.clear()
	if _scene != null and _dialogue == null:
		var found := _scene.find_children("*", "StoryDialogue", true, false)
		if not found.is_empty():
			_dialogue = found[0]
	if StoryMode.beat != _beat:
		_beat = StoryMode.beat
		var b := StoryMode.current()
		_events["beats"].append({ "t": snappedf(t, 0.001), "id": b["id"], "type": b["type"], "stage": b["stage"] })
		print("t=%6.2f  beat %s %s" % [t, b["id"], b["type"]])
		_driver = null
	_watch_dialogue()
	if _dialogue != null:
		# Nobody presses anything in a trailer: drop the "CLICK / SPACE" prompts.
		_dialogue._more.visible = false
		_dialogue._card_hint.visible = false
	_drive()
	_camera()
	if clean:
		if _dialogue != null:
			_dialogue.visible = false
		if _scene != null and "session" in _scene and _scene.session != null:
			_scene.session.set_clean_feed(true)
	if t >= length and not _done:
		_done = true
		var f := FileAccess.open(ProjectSettings.globalize_path(out_dir.path_join(out_name + ".events.json")), FileAccess.WRITE)
		f.store_string(JSON.stringify(_events, "  "))
		f.close()
		return true
	return false


## Log each piece of the story's 2D layer the moment its text changes.
func _watch_dialogue() -> void:
	if _dialogue == null:
		return
	var d := _dialogue
	_note("speaker", d._name.text if d._panel.visible else "")
	_note("line", d._text.text if d._panel.visible else "")
	_note("caption", d._caption.text if d._caption.visible else "")
	_note("stamp", d._stamp.text if d._stamp.visible else "")
	_note("subtitle", d._subtitle.text if d._subtitle.visible else "")
	_note("card", d._card_title.text if d._card.visible else "")
	_note("phone", str(d._feed.get_child_count()) if d._phone.visible else "")
	_note("comic", "on" if d._comic.visible else "")
	_note("black", "on" if d._black.color.a > 0.5 else "")


func _note(kind: String, value: String) -> void:
	if _seen.get(kind, "") == value:
		return
	_seen[kind] = value
	var e := { "t": snappedf(t, 0.001), "kind": kind, "text": value }
	if kind == "line":
		e["speaker"] = _seen.get("speaker", "")
	_events["lines"].append(e)


## The probe's AI: drives every drive beat, teleports into the place for drive-to beats.
func _drive() -> void:
	if _scene == null or not ("session" in _scene) or _scene.session == null or _scene.session.car == null:
		return
	var b := StoryMode.current()
	var session: DriveSession = _scene.session
	var car := session.car
	var director: StoryDirector = _scene.get_node_or_null("StoryDirector")
	if director == null:
		return
	match b["type"]:
		"goto":
			var area: Rect2 = HubLayout.PLACES[b["place"]]["area"]
			var c := area.get_center()
			if not area.has_point(Vector2(car.global_position.x, -car.global_position.z)):
				car.place(HubLayout.pos(c.x, c.y, 0.3), car.rotation.y)
		"race", "practice", "attack", "sectors", "daylight", "crash":
			var track: TrackData = director._loop_course() if b.get("course", "") == "loop" else StoryDirector.PASS_TRACK
			var jumped := car.global_position.distance_to(_last_pos) > 25.0
			if _driver == null or jumped:
				_driver = AiDriver.new(car, track, 1.0, 0.0)
				_driver.racing = true
			var me := _driver
			car.input_source = func() -> VehicleTypes.DriverInput:
				var i := me.input()
				return session.input_filter.call(i) if session.input_filter.is_valid() else i
	_last_pos = car.global_position


func _camera() -> void:
	if cams.is_empty() or _scene == null or not ("session" in _scene) or _scene.session == null:
		return
	var want := ""
	for c in cams:
		if t >= c[0]:
			want = c[1]
	if want == "" or not GAME_SHOTS.has(want):
		return
	var cam: ChaseCamera = _scene.session.camera
	if cam.mode != GAME_SHOTS[want] and cam.target != null:
		cam.mode = GAME_SHOTS[want]
		_events["marks"].append({ "t": snappedf(t, 0.001), "what": "cam " + want })
