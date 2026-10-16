extends SceneTree
## One AI car alone down Pass 1 (headless, 4×): time, spins (backwards travel) and recoveries.
## `godot --headless --path . -s res://tests/probe_ai_solo.gd -- preset mu brake skill`

var _scene
var _ai: AiDriver
var _t := 0.0
var _spins := 0
var _backwards := false
var _start_t := -1.0
var _args := []
var _hist := []


func _initialize() -> void:
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 64
	GameMenu.skip_title = true
	_args = OS.get_cmdline_user_args()
	AiDriver.plan_mu = float(_args[1])
	AiDriver.plan_brake = float(_args[2])
	if _args.size() > 4: AiDriver.steer_gain = float(_args[4])
	if _args.size() > 5: AiDriver.throttle_steer_cut = float(_args[5])
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)


func _physics_process(delta: float) -> bool:
	_t += delta
	if _ai == null:
		_scene.time_attack.free_drive()
		var car: CarBody = _scene.car
		car.set_preset(_args[0])
		var pose: Dictionary = _scene.track.pose_at(_scene.track.start_distance)
		car.place(pose["position"], pose["heading"])
		_ai = AiDriver.new(car, _scene.track, float(_args[3]), 0.0)
		car.input_source = _ai.input
		return false
	if _t > 0.5 and _start_t < 0.0:
		_ai.racing = true
		_start_t = _t
	var v: float = -_scene.car.linear_velocity.dot(_scene.car.global_basis.z)
	_hist.append("%.0fm v%.0f plan%.0f thr%.2f brk%.2f st%+.2f slip%+.0f" % [_ai.distance, _scene.car.linear_velocity.length() * 3.6, _ai._plan[_ai._index] * 3.6, _scene.car.last_input.throttle, _scene.car.last_input.brake, _scene.car.last_input.steer, rad_to_deg(_scene.car.model.diagnostics.body_slip)])
	if _hist.size() > 400:
		_hist = _hist.slice(-400)
	if v < -2.0 and not _backwards:
		_spins += 1
		print("SPIN at %.0f m; 3 s, 2 s, 1 s, 0.5 s before:" % _ai.distance)
		for back in [360, 240, 120, 60]:
			if _hist.size() > back: print("   ", _hist[-back])
	_backwards = v < -2.0
	# Slow stretches after the launch: where the car crawls (under 12 km/h), once per second.
	if _t - _start_t > 6.0 and absf(v) < 3.3 and fmod(_t, 1.0) < 1.0 / 120.0:
		print("SLOW t=%.0f at %.0f m lat %.1f  %s" % [_t - _start_t, _ai.distance,
			_scene.track.lateral_offset(_scene.car.global_position, _ai._index), _hist[-1]])
	if _ai.distance >= _scene.track.finish_distance:
		print("%s %s  time %.1f s  spins %d" % [_args[0], " ".join(_args.slice(1)), _t - _start_t, _spins])
		quit(0)
	if _t > 240.0:
		print("%s mu=%s brake=%s skill=%s  TIMEOUT at %.0f m spins %d" % [_args[0], _args[1], _args[2], _args[3], _ai.distance, _spins])
		quit(1)
	return false
