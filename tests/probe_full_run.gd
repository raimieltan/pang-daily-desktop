extends SceneTree
## End to end: an AI drives one full time attack on Pass 1 through the real scene (headless),
## then drives it again. Checks the first run writes a record, a ghost and the best sectors, and
## that the second run's results card compares against them. Records go to a probe directory,
## never the player's. Exits 0 when both runs finished and the files are right.
## `godot --headless --fixed-fps 120 --path . -s res://tests/probe_full_run.gd`

var _scene
var _ta: TimeAttack
var _driver: AiDriver
var _t := 0.0
var _runs := 0
var _finished := false
var _started := false
var _last_pos := Vector3.ZERO


func _initialize() -> void:
	Engine.max_physics_steps_per_frame = 64
	GameMenu.skip_title = true
	TimeAttackRecords.DIR = "user://time_attack_probe/"
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(TimeAttackRecords.DIR)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TimeAttackRecords.DIR + f))
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)


func _physics_process(delta: float) -> bool:
	_t += delta
	if _ta == null:
		_ta = _scene.time_attack
		_ta.finished.connect(_on_finished)
	if not _started and _t > 1.0:
		_started = true
		_start_run()
	if _finished:
		return false
	# A restart teleports the car to the grid a step later: the driver's place on the road is
	# stale after the jump, so it gets a fresh one (as probe_story does).
	var pos: Vector3 = _scene.session.car.global_position
	if _driver and pos.distance_to(_last_pos) > 25.0:
		_attach_driver()
	_last_pos = pos
	var run := _ta.run
	if run and int(_t / 10.0) != int((_t - delta) / 10.0):
		print("t=%5.1f run %d phase=%d time=%s progress=%.0f cp=%d kmh=%.0f" % [_t, _runs + 1, run.phase,
			TimeAttackRun.format_time(run.time), run.progress, run.next_checkpoint, _scene.session.car.speed_kmh()])
	if _t > 600.0:
		print("TIMEOUT")
		quit(1)
	return false


func _start_run() -> void:
	_ta.restart(false)
	_attach_driver()


func _attach_driver() -> void:
	var session: DriveSession = _scene.session
	_driver = AiDriver.new(session.car, _scene.track, 1.0, 0.0)
	_driver.racing = true
	var me := _driver
	session.car.input_source = func() -> VehicleTypes.DriverInput:
		var i := me.input()
		return session.input_filter.call(i) if session.input_filter.is_valid() else i


func _on_finished(time: float, record: bool) -> void:
	_runs += 1
	var id := _ta._car_id()
	var best := TimeAttackRecords.load_best(_ta.track_id, id)
	var ghost := TimeAttackRecords.load_ghost(_ta.track_id, id)
	var sectors := TimeAttackRecords.load_sectors(_ta.track_id, id)
	print("FINISH run %d %s record=%s best=%s ghost frames=%d sectors=%s" % [_runs, TimeAttackRun.format_time(time), record,
		best.get("time"), ghost.size() / 7, sectors])
	print("CARD:\n" + "\n".join(RaceHud.result_lines(time, _ta.run.splits, best.get("splits", []), sectors,
		float(best.get("time", -1.0)), record, "BEST")))
	var ok := best.has("time") and ghost.size() > 100 and sectors.size() == 4
	if _runs == 1:
		ok = ok and record
		if not ok:
			quit(1)
		_start_run()
		return
	_finished = true
	quit(0 if ok else 1)
