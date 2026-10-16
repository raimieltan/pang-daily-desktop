extends SceneTree
## Story mode screenshots (needs a window, not --headless): starts the story at a beat on the
## probe's save (run tests/probe_story.gd first so the passes and the crash log exist), lets it
## play for a while with the AI driving, and saves a PNG every `every` seconds.
## `godot --path . -s res://tools/story_shot.gd -- <out_dir> <beat_id> [seconds] [every]`
## Lines hold on screen for 2.5 s each (StoryDialogue.auto_advance) so they are in the shots.

var _out := ""
var _name := ""
var _t := 0.0
var _until := 12.0
var _every := 3.0
var _next := 1.0
var _shot := 0
var _driver: AiDriver
var _last := Vector3.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://story_shots"
	_name = args[1] if args.size() > 1 else "s01"
	_until = float(args[2]) if args.size() > 2 else 12.0
	_every = float(args[3]) if args.size() > 3 else 3.0
	_next = _every
	DirAccess.make_dir_recursive_absolute(_out)
	StoryMode.save_path = "user://story_probe.json"
	StoryDialogue.auto_advance = 2.5
	StoryMode.load_save()
	StoryMode.goto.call_deferred(self, maxi(0, StoryScript.index_of(_name)))


func _process(delta: float) -> bool:
	_t += delta
	_drive()
	if _t >= _next:
		_next += _every
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s/%s_%02d.png" % [_out, _name, _shot]
		img.save_png(path)
		print("saved ", path, "  beat ", StoryMode.current()["id"])
		_shot += 1
	if _t > _until:
		quit(0)
	return false


func _drive() -> void:
	var scene := current_scene
	if scene == null or not ("session" in scene) or scene.session == null:
		return
	var b := StoryMode.current()
	if not (b["type"] in ["race", "practice", "attack", "sectors", "daylight", "crash"]):
		return
	var session: DriveSession = scene.session
	var car := session.car
	var director: StoryDirector = scene.get_node_or_null("StoryDirector")
	if director == null:
		return
	var track: TrackData = director._loop_course() if b.get("course", "") == "loop" else StoryDirector.PASS_TRACK
	if _driver == null or car.global_position.distance_to(_last) > 25.0:
		_driver = AiDriver.new(car, track, 1.0, 0.0)
		_driver.racing = true
		var me := _driver
		car.input_source = func() -> VehicleTypes.DriverInput:
			var i := me.input()
			return session.input_filter.call(i) if session.input_filter.is_valid() else i
	_last = car.global_position
