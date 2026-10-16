extends SceneTree
## End-to-end SP battle, headless at 4× speed: the player's car gets an AI driver too and battles
## one rival down Pass 1. Prints both gauges every 5 s and the outcome; exits 0 once it is decided.
## `godot --headless --path . -s res://tests/probe_sp_battle.gd -- [player_skill] [rival_index]`

var _scene
var _vs: VsBattle
var _me: AiDriver
var _t := 0.0
var _started := false


func _initialize() -> void:
	Engine.time_scale = 4.0
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
		_scene.car.input_source = func(): return _vs._filter_input(_me.input())
		_vs.finished.connect(func(place):
			var sp := _vs.sp
			print("SP OVER %s (%s) you=%.1f %s=%.1f at %s" % ["WIN" if place == 1 else "LOSE", sp.reason,
				sp.sp[0], _vs.field[0]["name"], sp.sp[1], TimeAttackRun.format_time(_vs._clock)])
			quit(0))
		return false
	if _vs.run:
		_me.racing = _vs.run.phase == TimeAttackRun.Phase.RUNNING
	if fmod(_t, 5.0) < delta and _vs.sp:
		var sp := _vs.sp
		print("t=%5.1f phase=%d me=%5.0f m  %s=%5.0f m  gap=%4.1f  sp you=%5.1f rival=%5.1f" % [_t, sp.phase,
			_vs.run.progress, _vs.field[0]["name"], _vs.drivers[0].distance, sp.gap, sp.sp[0], sp.sp[1]])
	if _t > 240.0:
		print("TIMEOUT")
		quit(1)
	return false
