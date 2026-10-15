extends SceneTree
## End-to-end VS battle, headless at 4× speed: the player's car gets an AI driver too, so all four
## race Pass 1. Prints positions every 10 s and the finish; exits 0 if everyone finished.
## `godot --headless --path . -s res://tests/probe_vs_battle.gd -- [player_skill] [opponents]`

var _scene
var _vs: VsBattle
var _me: AiDriver
var _t := 0.0
var _started := false
var _done_at := -1.0


func _initialize() -> void:
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 64
	GameMenu.skip_title = true
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)


func _physics_process(delta: float) -> bool:
	_t += delta
	if not _started:
		_started = true
		_vs = _scene.vs_battle
		if OS.get_cmdline_user_args().size() > 1:
			_vs.opponents = int(OS.get_cmdline_user_args()[1])
		_scene.time_attack.free_drive()
		_vs.start()
		_scene.intro.skip()
		var skill := float(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 0.95
		_me = AiDriver.new(_scene.car, _scene.track, skill, 0.0)
		_scene.car.input_source = func(): return _vs._filter_input(_me.input())
		_vs.finished.connect(func(place): print("PLAYER FINISH place=%d time=%s" % [place, TimeAttackRun.format_time(_vs.run.time)]))
		return false
	if _vs.run:
		_me.racing = _vs.run.phase == TimeAttackRun.Phase.RUNNING
	if fmod(_t, 10.0) < delta and _vs.run:
		var line := "t=%5.1f run=%s me=%5.0f m %3.0f km/h" % [_t, TimeAttackRun.format_time(_vs.run.time), _vs.run.progress, _scene.car.speed_kmh()]
		for k in _vs.drivers.size():
			line += " | %s %5.0f m %3.0f" % [VsBattle.RIVALS[k]["name"], _vs.drivers[k].distance, _vs.rivals[k].speed_kmh()]
		print(line)
	var all_done: bool = _vs.run != null and _vs.run.phase == TimeAttackRun.Phase.FINISHED and _vs._finish_times.size() == _vs.drivers.size()
	if all_done and _done_at < 0.0:
		_done_at = _t
		print(_vs._standings_text())
		quit(0)
	if _t > 300.0:
		print("TIMEOUT finished=%s" % [_vs._finish_times])
		if _vs.run: print(_vs._standings_text())
		quit(1)
	return false
