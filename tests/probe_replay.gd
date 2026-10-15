extends SceneTree
## Spectate + replay end to end, headless at 4×: a VS battle with the player's car on autopilot and
## the cinematic camera, then the replay from the start, a seek, every shot type, and back to the
## race. Checks the replay poses the cars on their recorded path and the race resumes where it was.
## `godot --headless --path . -s res://tests/probe_replay.gd`

var _scene
var _session: DriveSession
var _replay: Replay
var _t := 0.0
var _phase := 0
var _phase_t := 0.0
var _before := []
var _start_pose := Vector3.ZERO
var _fail := false
var _shots := {}


func _initialize() -> void:
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 64
	GameMenu.skip_title = true
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	_fail = _fail or not ok


func _physics_process(delta: float) -> bool:
	_t += delta
	_phase_t += delta
	match _phase:
		0:
			_session = _scene.session
			_replay = _session.replay
			_scene.menu._start_spectate()
			_scene.intro.skip()
			_next()
		1:
			if _scene.vs_battle._in_intro:
				_scene.intro.skip()
				_phase_t = 0.0
				return false
			if _phase_t > 1.0 and _scene.vs_battle.run and _start_pose == Vector3.ZERO:
				_start_pose = _session.car.global_position
			if _phase_t > 3.0 and _phase_t - delta <= 3.0:
				_check(_session.autopilot != null, "autopilot on in spectate")
				_check(_session.camera.mode == ChaseCamera.Mode.CINEMATIC, "cinematic camera in spectate")
			_shots[_session.camera.director.shot] = true
			if _phase_t > 30.0:
				var r: TimeAttackRun = _scene.vs_battle.run
				_check(r != null and r.progress > 200.0, "autopilot drove %.0f m in 26 s" % (r.progress if r else 0.0))
				_check(_replay.cars.size() == 1 + _scene.vs_battle.rivals.size(), "recording every car (%d)" % _replay.cars.size())
				_check(_replay.duration() > 20.0, "recorded %.1f s" % _replay.duration())
				_before = _replay.cars.map(func(c): return c.global_position)
				_replay.start()
				_next()
		2:
			if _phase_t > 0.5 and _phase_t - delta <= 0.5:
				# ~0.5 s into the replay the player should be near where it was 0.5 s after recording began.
				var rec := _session.car.global_position
				_check(rec.distance_to(_start_pose) < 40.0, "replay starts at the run start (%.1f m off grid)" % rec.distance_to(_start_pose))
				_check(not _session.car.replaying or _session.car.collision_layer == 0, "replayed cars have no collisions")
			_shots[_session.camera.director.shot] = true
			if _phase_t > 4.0 and _phase_t - delta <= 4.0:
				_replay.time = 15.0
				_replay._reset_fx()
			if _phase_t > 5.0 and _phase_t - delta <= 5.0:
				_check(absf(_replay.time - 16.0) < 0.2, "seek holds (t=%.2f)" % _replay.time)
				for s in CinematicDirector.Shot.values():
					_session.camera.director.shot = s
					_session.camera.director._shot_time = 0.0
			if _phase_t > 6.0:
				_replay.stop()
				_check(not _session.car.replaying and _session.car.collision_layer != 0, "cars live again")
				_next()
		3:
			if _phase_t <= delta * 1.5:
				# One step after the replay: each car within a step's travel of where it left off.
				var drift := 0.0
				for k in _replay.cars.size():
					var c: CarBody = _replay.cars[k]
					drift = maxf(drift, c.global_position.distance_to(_before[k]) - c.linear_velocity.length() * delta * 2.0)
				_check(drift < 1.0, "cars back where the race left them (%.2f m)" % drift)
			if _phase_t > 5.0:
				var r: TimeAttackRun = _scene.vs_battle.run
				_check(r.progress > 250.0, "race carries on after the replay (%.0f m)" % r.progress)
				print("shots seen: ", _shots.keys().map(func(s): return CinematicDirector.SHOT_NAMES[s]))
				quit(1 if _fail else 0)
	if _t > 200.0:
		print("TIMEOUT phase %d" % _phase)
		quit(1)
	return false


func _next() -> void:
	_phase += 1
	_phase_t = 0.0
