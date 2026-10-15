extends SceneTree
## End-to-end: an autopilot drives Pass 1 through the real time-attack scene (headless, 4× speed).
## Pure pursuit on the centerline, speed planned from the curvature ahead. Prints events and the
## result; exits 0 if the run finished and a record was written.
var _scene
var _ta: TimeAttack
var _events := PackedStringArray()
var _wall_time := 0.0
var _finished := false

func _initialize() -> void:
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 64
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://time_attack/touge_01__banwa_dalagan_1996_fwd_worn_sedan.json"))
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)

func _autopilot() -> VehicleTypes.DriverInput:
	var car: CarBody = _scene.car
	var track: TrackData = _scene.track
	var i := track.nearest_index(car.global_position, _ta._index_hint)
	var speed := car.linear_velocity.length()
	var ahead := track.points[mini(i + int(5.0 + speed * 0.55), track.points.size() - 1)]
	var local := car.global_transform.affine_inverse() * ahead
	var steer := clampf(atan2(local.x, -local.z) * 2.2, -1.0, 1.0)
	# Tightest curvature in the braking window ahead → corner speed (μ ≈ 0.72 on stock tires).
	var k := 0.0
	for j in range(i + 4, mini(i + 4 + int(10.0 + speed * 2.2), track.points.size() - 2), 3):
		var a := track.forwards[j - 3]
		var b := track.forwards[j + 1]
		k = maxf(k, Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)) / 4.0 if true else 0.0)
		k = maxf(k, absf(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z))) / 4.0)
	var target := minf(30.0, sqrt(0.72 * 9.81 / maxf(k, 0.0005)))
	var input := VehicleTypes.DriverInput.make(0, 0, steer, 0, "ai")
	if speed < target - 1.0: input.throttle = 1.0
	elif speed > target + 1.5: input.brake = clampf((speed - target) / 6.0, 0.2, 1.0)
	else: input.throttle = 0.35
	return input

func _physics_process(delta: float) -> bool:
	if _ta == null:
		_ta = _scene.time_attack
		_scene.session._input = null
		_scene.car.input_source = _filtered
		_ta.finished.connect(func(t, record): print("FINISH %s record=%s" % [TimeAttackRun.format_time(t), record]); _finished = true)
	_wall_time += delta
	var run := _ta.run
	if fmod(_wall_time, 10.0) < delta:
		print("t=%5.1f phase=%d time=%s progress=%.0f/%.0f cp=%d splits=%s kmh=%.0f" % [_wall_time, run.phase, TimeAttackRun.format_time(run.time), run.progress, run.finish_distance, run.next_checkpoint, Array(run.splits).map(func(x): return snappedf(x, 0.01)), _scene.car.speed_kmh()])
	if _finished:
		var best := TimeAttackRecords.load_best("touge_01", "banwa_dalagan_1996_fwd_worn_sedan")
		var ghost := TimeAttackRecords.load_ghost("touge_01", "banwa_dalagan_1996_fwd_worn_sedan")
		print("saved best=%s ghost frames=%d" % [best.get("time"), ghost.size() / 7])
		quit(0 if best.has("time") and ghost.size() > 100 else 1)
	if _wall_time > 240.0:
		print("TIMEOUT")
		quit(1)
	return false

func _filtered() -> VehicleTypes.DriverInput:
	return _ta._filter_input(_autopilot())
