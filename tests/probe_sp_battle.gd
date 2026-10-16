extends SceneTree
## End-to-end SP battle, headless at 4× speed: the player's car gets an AI driver too and battles
## one rival down Pass 1. Prints both gauges every 5 s and the outcome; exits 0 once it is decided.
## `godot --headless --fixed-fps 120 --path . -s res://tests/probe_sp_battle.gd -- [player_skill] [rival_index]`
## --fixed-fps 120 steps true 120 Hz physics as fast as the CPU allows (deterministic); without it
## the probe runs at 4× time scale, which coarsens every physics step to 1/30 s.

var _scene
var _vs: VsBattle
var _me: AiDriver
var _t := 0.0
var _started := false


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
	var args := OS.get_cmdline_user_args()
	if not _started:
		_started = true
		_vs = _scene.vs_battle
		_vs.sp_rival = int(args[1]) if args.size() > 1 else 0
		_scene.time_attack.free_drive()
		_vs.start()
		_scene.intro.skip()
		var skill := float(args[0]) if args.size() > 0 else 0.95
		_me = AiDriver.new(_scene.car, _scene.track, skill, 0.0)
		_me.others = _vs.field_cars()
		_scene.car.input_source = func(): return _vs._filter_input(_me.input())
		_vs.finished.connect(func(place):
			var sp := _vs.sp
			print("SP OVER %s (%s) you=%.1f %s=%.1f at %s recoveries you=%d rival=%d" % ["WIN" if place == 1 else "LOSE", sp.reason,
				sp.sp[0], _vs.field[0]["name"], sp.sp[1], TimeAttackRun.format_time(_vs._clock), _me.recoveries, _vs.drivers[0].recoveries])
			quit(0))
		return false
	if _vs.run:
		_me.racing = _vs.run.phase == TimeAttackRun.Phase.RUNNING
	if fmod(_t, 5.0) < delta and _vs.sp:
		var sp := _vs.sp
		print("t=%5.1f phase=%d me=%5.0f m  %s=%5.0f m  gap=%4.1f  sp you=%5.1f rival=%5.1f" % [_t, sp.phase,
			_vs.run.progress, _vs.field[0]["name"], _vs.drivers[0].distance, sp.gap, sp.sp[0], sp.sp[1]])
	# PROBE_TRACE=1: both cars, pedals, gear and what the traffic logic asks for, 16–30 s.
	if OS.has_environment("PROBE_TRACE") and _vs.sp and fmod(_t, 0.5) < delta and _t > 16.0 and _t < 30.0:
		var c: CarBody = _scene.car
		var r: CarBody = _vs.rivals[0]
		var tr: Dictionary = _me._traffic(c.global_position, c.linear_velocity.length())
		print("TR t=%4.1f me %4.0f m %3.0f km/h lat %4.1f thr %.2f brk %.2f | rival %4.0f m %3.0f km/h lat %4.1f | cap %s lane %s plan %3.0f gear %d rpm %.0f preset %s tire %s" % [_t,
			_me.distance, c.speed_kmh(), _scene.track.lateral_offset(c.global_position, _me._index), c.last_input.throttle, c.last_input.brake,
			_vs.drivers[0].distance, r.speed_kmh(), _scene.track.lateral_offset(r.global_position, _me._index),
			str(snappedf(tr["speed"] * 3.6, 1)), str(snappedf(tr["lane"], 0.1)), _me._plan[_me._index] * 3.6, _scene.car.model.mechanics.gear, _scene.car.model.mechanics.engine_rpm, _scene.car.preset, _scene.car.tire_product])
	# PROBE_DRIVE=1: drivetrain and per-wheel slip / load / lateral force, 14–26 s.
	if OS.has_environment("PROBE_DRIVE") and fmod(_t, 0.5) < delta and _t > 14.0 and _t < 26.0:
		var m: FourWheelDynamics = _scene.car.model.mechanics
		var w := m.wheels
		print("DR t=%4.1f %3.0f km/h g%d %4.0f rpm thr_in %.2f clutch %.2f axle %5.0f slip %+.2f %+.2f %+.2f %+.2f load %4.0f %4.0f %4.0f %4.0f lat %+.1f %+.1f %+.1f %+.1f" % [_t,
			_scene.car.speed_kmh(), m.gear, m.engine_rpm, _scene.car.model.state.throttle, m.clutch, m.axle_torque,
			w[0].slip_ratio, w[1].slip_ratio, w[2].slip_ratio, w[3].slip_ratio,
			w[0].vertical_load, w[1].vertical_load, w[2].vertical_load, w[3].vertical_load,
			w[0].lateral_force / 1000.0, w[1].lateral_force / 1000.0, w[2].lateral_force / 1000.0, w[3].lateral_force / 1000.0])
	if _t > 240.0:
		print("TIMEOUT")
		quit(1)
	return false
