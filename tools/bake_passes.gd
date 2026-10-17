extends SceneTree
## Bakes the line study's floor: an AI drives "A Line Study" (s06) headless, on the limit, and the
## three passes it records are written to StoryMode.BAKED_PATH. In play, a practice pass slower
## than the baked one in its slot takes the baked driving (StoryMode.add_pass), so the Ghost Line
## is never a lap the study was driven badly enough to beat.
## `godot --headless --fixed-fps 120 --path . -s res://tools/bake_passes.gd -- [skill]`
## Story progress goes to user://story_bake.json, never the player's save.

const SKILL := 1.05
const TIMEOUT := 900.0

var _t := 0.0
var _scene: Node
var _driver: AiDriver
var _last_pos := Vector3.ZERO
var _study := -1
var _skill := SKILL


func _initialize() -> void:
	Engine.max_physics_steps_per_frame = 64
	StoryMode.save_path = "user://story_bake.json"
	StoryMode.use_floor = false
	StoryDialogue.auto_advance = 0.05
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_skill = float(args[0])
	_study = StoryScript.index_of("s06")
	StoryMode.load_save()
	StoryMode.record = {}
	StoryMode.results = {}
	StoryMode.completed = false
	StoryMode.goto.call_deferred(self, _study)


func _physics_process(delta: float) -> bool:
	_t += delta
	if current_scene != _scene:
		_scene = current_scene
		_driver = null
	var passes: Array = StoryMode.record.get("passes", [])
	if StoryMode.beat > _study and passes.size() >= 3:
		_write(passes)
		quit(0)
		return false
	_drive()
	if _t > TIMEOUT:
		print("TIMEOUT with %d passes" % passes.size())
		quit(1)
	return false


func _drive() -> void:
	if _scene == null or not ("session" in _scene) or _scene.session == null or _scene.session.car == null:
		return
	if StoryMode.current().get("type", "") != "practice":
		return
	var session: DriveSession = _scene.session
	var car := session.car
	var jumped := car.global_position.distance_to(_last_pos) > 25.0
	if _driver == null or jumped:
		_driver = AiDriver.new(car, StoryDirector.PASS_TRACK, _skill, 0.0)
		_driver.racing = true
	var me := _driver
	car.input_source = func() -> VehicleTypes.DriverInput:
		var i := me.input()
		return session.input_filter.call(i) if session.input_filter.is_valid() else i
	_last_pos = car.global_position


func _write(passes: Array) -> void:
	var out := []
	for p in passes:
		out.append({ "label": p["label"], "frames": p["frames"], "splits": p["splits"], "time": p["time"] })
		print("  %-52s %s  splits %s" % [p["label"], TimeAttackRun.format_time(float(p["time"])), p["splits"]])
	var f := FileAccess.open(StoryMode.BAKED_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("BAKED %d passes at skill %.2f -> %s  cut=%s" % [out.size(), _skill, StoryMode.BAKED_PATH,
		TimeAttackRun.format_time(StoryMode.ghost_line().time)])
