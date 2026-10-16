extends SceneTree
## The barangay hub, headless: builds it, lets the cruisers drive the loop, checks the player sits
## on the ground at Kyo next to a parked rival, then challenges that rival and checks the SP
## battle starts on Pass 1 with the right rival and car. Exits 0 when all of that holds.
## `godot --headless --fixed-fps 120 --path . -s res://tests/probe_hub.gd`

var _hub: Node3D
var _t := 0.0
var _phase := 0
var _start_pos: Array[Vector3] = []
var _fail := 0


func _initialize() -> void:
	Engine.max_physics_steps_per_frame = 64
	var started := Time.get_ticks_msec()
	HubChallenge.car_id = "silak_box"
	_hub = load(HubChallenge.HUB_SCENE).instantiate()
	root.add_child(_hub)
	current_scene = _hub
	print("hub built in %d ms" % (Time.get_ticks_msec() - started))


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		_fail += 1


func _physics_process(delta: float) -> bool:
	_t += delta
	if _phase == 0 and _t > 0.2:
		_phase = 1
		for c in _hub.cruisers:
			_start_pos.append(c.global_position)
	elif _phase == 1 and _t > 20.0:
		_phase = 2
		var car: CarBody = _hub.session.car
		_check(absf(car.global_position.y) < 1.0, "player on the ground at y=%.2f" % car.global_position.y)
		_check(car.linear_velocity.length() < 0.5, "player parked (%.2f m/s)" % car.linear_velocity.length())
		_check(_hub.session.car_spec["id"] == "silak_box", "drove up in the Silak Box")
		for k in _hub.cruisers.size():
			var c: CarBody = _hub.cruisers[k]
			var moved := c.global_position.distance_to(_start_pos[k])
			var speed := c.linear_velocity.length() * 3.6
			_check(moved > 60.0 and absf(c.global_position.y) < 1.5,
				"cruiser %s moved %.0f m, %.0f km/h, y=%.2f, recoveries %d" % [c.name, moved, speed,
				c.global_position.y, _hub.cruiser_drivers[k].recoveries])
		for k in _hub.parked.size():
			var p: CarBody = _hub.parked[k]
			_check(p.linear_velocity.length() < 0.3 and absf(p.global_position.y) < 1.0, "%s parked at Kyo" % p.name)
		# Roll up beside the nearest parked rival and challenge.
		var target: CarBody = _hub.parked[0]
		car.place(target.global_position + Vector3(-4.8, 0, 0), car.rotation.y)
	elif _phase == 2 and _t > 21.0:
		_phase = 3
		var car: CarBody = _hub.session.car
		_hub._update_prompt(Vector2(car.global_position.x, -car.global_position.z))
		print("prompt: %s | %s" % [_hub._prompt.text, _hub._line.text])
		_check(_hub._prompt.text.contains("CHALLENGE JUNJUN"), "Kyo prompt offers JUNJUN")
		_hub._action.call()
	elif _phase == 3 and _t > 23.0:
		_phase = 4
		var scene := current_scene
		_check(scene != null and scene.name == "Touge", "on Pass 1 (%s)" % (scene.name if scene else "none"))
		if scene:
			_check(scene.vs_battle.active and scene.vs_battle.sp_rival == 0, "SP battle against JUNJUN running")
			_check(scene.session.car_spec["id"] == "silak_box", "same car on the pass")
			_check(scene._kyo_hint != null and not scene._kyo_hint.visible, "back-to-Kyo hint waits for the result")
		print("PROBE %s (%d failures)" % ["PASS" if _fail == 0 else "FAIL", _fail])
		quit(0 if _fail == 0 else 1)
	return false
