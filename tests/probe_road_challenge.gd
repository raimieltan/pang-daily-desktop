extends SceneTree
## Road challenge end to end, headless: free drive from the menu with the player's car on an AI
## driver; a rival cruises ahead, the player closes up, flashes, and the SP battle runs to a result.
## Exits 0 once a challenge started from the road has been decided.
## `godot --headless --fixed-fps 120 --path . -s res://tests/probe_road_challenge.gd -- [player_skill]`

var _scene
var _me: AiDriver
var _t := 0.0
var _started := false
var _challenged := false


func _initialize() -> void:
	Engine.time_scale = 1.0 if "--fixed-fps" in OS.get_cmdline_args() else 4.0
	Engine.max_physics_steps_per_frame = 64
	GameMenu.skip_title = true
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)


func _physics_process(delta: float) -> bool:
	_t += delta
	var rc: RoadChallenge = _scene.road_challenge
	var vs: VsBattle = _scene.vs_battle
	if not _started:
		_started = true
		_scene.menu._start_free_drive()
		var args := OS.get_cmdline_user_args()
		_me = AiDriver.new(_scene.car, _scene.track, float(args[0]) if args.size() > 0 else 0.95, 0.0)
		_me.racing = true
		_scene.car.input_source = func(): return _me.input()
		vs.finished.connect(func(place):
			print("ROAD SP OVER %s (%s) you=%.1f %s=%.1f at %s, started at %.0f m" % ["WIN" if place == 1 else "LOSE",
				vs.sp.reason, vs.sp.sp[0], vs.field[0]["name"], vs.sp.sp[1], TimeAttackRun.format_time(vs.sp.time), vs.run.start_distance])
			quit(0))
		return false
	if not _challenged:
		_me.others = [_scene.car, rc.cruiser()] if rc.cruiser() else []
		if fmod(_t, 2.0) < delta and rc.cruiser():
			print("t=%5.1f me %4.0f m %3.0f km/h  cruiser %4.0f m %3.0f km/h  open=%s" % [_t, _me.distance, _scene.car.speed_kmh(),
				rc._driver.distance, rc.cruiser().speed_kmh(), rc.can_challenge()])
		if rc.can_challenge():
			rc.flash()
			_challenged = vs.active and vs.sp != null
			print("CHALLENGE at t=%.1f me %.0f m vs %s, armed at %.0f m, active=%s" % [_t, _me.distance, vs.field[0]["name"], vs.sp.arm_distance, vs.active])
			# The player's driver keeps going; it sees the battle field now.
			_me.others = vs.field_cars()
	elif fmod(_t, 3.0) < delta:
		print("  t=%5.1f phase=%d gap=%4.1f sp you=%5.1f rival=%5.1f" % [_t, vs.sp.phase, vs.sp.gap, vs.sp.sp[0], vs.sp.sp[1]])
	if _t > 200.0:
		print("TIMEOUT challenged=%s" % _challenged)
		quit(1)
	return false
