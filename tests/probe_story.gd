extends SceneTree
## The whole of "The Ghost Line", headless: lines auto-advance, evidence auto-answers, and an AI
## drives every drive beat (the practice passes it records become the Ghost Line). Prints each beat
## as it starts and what the story recorded; exits 0 when the story reaches its end.
## `godot --headless --fixed-fps 120 --path . -s res://tests/probe_story.gd -- [first_beat_id]`
## Saves to user://story_probe.json, never the player's save.

var _t := 0.0
var _beat := -1
var _scene: Node
var _last_pos := Vector3.ZERO
var _driver: AiDriver


func _initialize() -> void:
	Engine.max_physics_steps_per_frame = 64
	StoryMode.save_path = "user://story_probe.json"
	StoryDialogue.auto_advance = 0.05
	var args := OS.get_cmdline_user_args()
	var first := StoryScript.index_of(args[0]) if args.size() > 0 else 0
	if first > 0:
		# Resume mid-story on the last probe's record.
		StoryMode.load_save()
		StoryMode.completed = false
		StoryMode.goto.call_deferred(self, first)
	else:
		StoryMode.start_new.call_deferred(self)


func _physics_process(delta: float) -> bool:
	_t += delta
	if current_scene != _scene:
		_scene = current_scene
		_driver = null
	if StoryMode.completed and not StoryMode.active:
		print("STORY COMPLETE at %.0f s  passes=%d ghost=%s crash_frames=%d results=%s" % [_t,
			StoryMode.record.get("passes", []).size(), TimeAttackRun.format_time(StoryMode.ghost_line().time),
			StoryMode.unpack(StoryMode.record.get("crash", "")).size() / GhostLine.STRIDE, JSON.stringify(StoryMode.results)])
		quit(0)
		return false
	if StoryMode.beat != _beat:
		_beat = StoryMode.beat
		var b := StoryMode.current()
		print("t=%6.1f  beat %2d  %-6s %-9s %-6s %s" % [_t, _beat, b["id"], b["type"], b["stage"], b.get("title", b.get("place", ""))])
		_driver = null
	_drive()
	if _t > 3600.0:
		print("TIMEOUT at beat ", StoryMode.current()["id"])
		quit(1)
	return false


## Put an AI on the player's car for drive beats; teleport into the place for goto beats.
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
	# PROBE_CRASH=1: the night run's last approach, every 0.25 s.
	if OS.has_environment("PROBE_CRASH") and b["type"] == "crash" and fmod(_t, 0.25) < 1.0 / 120.0:
		var t := StoryDirector.PASS_TRACK
		var i := t.nearest_index(car.global_position)
		print("  crash t=%5.2f d=%6.1f %5.1f km/h lat %+.1f grip %.2f thr %.1f brk %.1f steer %+.2f" % [_t, i * t.spacing, car.speed_kmh(),
			t.lateral_offset(car.global_position, i), car.model.surface_grip, car.last_input.throttle, car.last_input.brake, car.last_input.steer])
