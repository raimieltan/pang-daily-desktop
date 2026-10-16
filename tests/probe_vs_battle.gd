extends SceneTree
## End-to-end VS battle, headless at 4× speed: the player's car gets an AI driver too, so all four
## race Pass 1. Prints positions every 10 s and the finish; exits 0 if everyone finished.
## `godot --headless --fixed-fps 120 --path . -s res://tests/probe_vs_battle.gd -- [player_skill] [opponents]`
## --fixed-fps 120 steps true 120 Hz physics as fast as the CPU allows (deterministic); without it
## the probe runs at 4× time scale, which coarsens every physics step to 1/30 s.

var _scene
var _vs: VsBattle
var _me: AiDriver
var _t := 0.0
var _started := false
var _done_at := -1.0


func _initialize() -> void:
	# With --fixed-fps 120 every frame is one true 120 Hz step and headless runs flat out; without
	# it, 4× time scale (coarser physics steps).
	Engine.time_scale = 1.0 if "--fixed-fps" in OS.get_cmdline_args() else 4.0
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
		_me.others = _vs.field_cars()
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
	# Stall log: a racing car under 15 km/h, once per second, with the nearest car to it.
	if _vs.run and _vs.run.phase == TimeAttackRun.Phase.RUNNING and fmod(_t, 1.0) < delta:
		var cars: Array = _vs.field_cars()
		var ds: Array = [_me] + _vs.drivers
		for i in cars.size():
			var c: CarBody = cars[i]
			if c.speed_kmh() < 15.0 and ds[i].distance < _scene.track.finish_distance:
				var near := INF
				for c2 in cars:
					if c2 != c:
						near = minf(near, c.global_position.distance_to(c2.global_position))
				print(("STALL t=%5.1f %s at %5.0f m lat %4.1f %3.0f km/h nearest car %4.1f m rec=%d" % [_t,
					"YOU" if i == 0 else _vs.field[i - 1]["name"], ds[i].distance,
					_scene.track.lateral_offset(c.global_position, _scene.track.nearest_index(c.global_position)),
					c.speed_kmh(), near, ds[i].recoveries]))
	var all_done: bool = _vs.run != null and _vs.run.phase == TimeAttackRun.Phase.FINISHED and _vs._finish_times.size() == _vs.drivers.size()
	if all_done and _done_at < 0.0:
		_done_at = _t
		print(_vs._standings_text())
		print("recoveries you=%d rivals=%s" % [_me.recoveries, _vs.drivers.map(func(d): return d.recoveries)])
		quit(0)
	if _t > 300.0:
		print("TIMEOUT finished=%s" % [_vs._finish_times])
		if _vs.run: print(_vs._standings_text())
		quit(1)
	return false
