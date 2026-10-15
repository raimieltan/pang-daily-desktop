extends RefCounted
## Parity with the TS sim: replays the scenarios of `tests/fixtures/ts_reference.json`
## (written by the TS repo's fixture probe) through the GDScript port and compares the traces.

const DT := 1.0 / 120.0

var errors: Array[String] = []
var _fixtures: Dictionary


func _init() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/ts_reference.json")
	_fixtures = JSON.parse_string(text)


func _close(label: String, actual: float, expected: float, tolerance: float) -> void:
	if absf(actual - expected) > tolerance:
		errors.append("%s: expected %.5f, got %.5f (tol %.5f)" % [label, expected, actual, tolerance])


func _run(scenario: Dictionary) -> Array[Dictionary]:
	var model := HandlingModel.new(HandlingPresets.resolve(scenario["preset"]))
	model.sync_motion(scenario["vx"], 0.0, 0.0)
	var contact := VehicleTypes.AxleContact.grounded()
	var samples: Array[Dictionary] = []
	var t := 0.0
	var frame := 0
	for phase in scenario["phases"]:
		var i: Dictionary = phase["input"]
		var input := VehicleTypes.DriverInput.make(i["throttle"], i["brake"], i["steer"], i.get("handbrake", 0.0), i.get("device", "ai"))
		for n in roundi(phase["seconds"] / DT):
			model.step(DT, input, contact)
			t += DT
			frame += 1
			if frame % 30 == 0:
				var s := model.state
				var m := model.mechanics
				samples.append({ "t": t, "vx": s.vx, "vy": s.vy, "yawRate": s.yaw_rate, "steer": s.steer_angle, "gear": m.gear,
					"rpm": m.engine_rpm, "w0": m.wheels[0].angular_velocity, "w2": m.wheels[2].angular_velocity,
					"frontGripUse": model.diagnostics.front_grip_use, "rearGripUse": model.diagnostics.rear_grip_use })
	return samples


## Compares every sample. Tolerances are loose enough for float-order differences, tight enough
## that any ported formula mistake shows up.
func _compare(name: String, keys: Dictionary) -> void:
	var expected: Array = _fixtures[name]["samples"]
	var actual := _run(_fixtures[name])
	if actual.size() != expected.size():
		errors.append("%s: %d samples, expected %d" % [name, actual.size(), expected.size()])
		return
	for i in actual.size():
		for key in keys:
			_close("%s t=%.2f %s" % [name, expected[i]["t"], key], actual[i][key], expected[i][key], keys[key])
		if errors.size() > 8:
			return


func test_launch_matches_ts() -> void:
	_compare("launch", { "vx": 0.02, "rpm": 5.0, "gear": 0.0, "w0": 0.05 })


func test_braking_matches_ts() -> void:
	_compare("brake", { "vx": 0.02, "w0": 0.05, "w2": 0.05 })


func test_step_steer_matches_ts() -> void:
	_compare("stepSteer", { "vx": 0.02, "vy": 0.01, "yawRate": 0.005, "steer": 0.001, "frontGripUse": 0.01 })


func test_handbrake_turn_matches_ts() -> void:
	_compare("handbrake", { "vx": 0.03, "vy": 0.02, "yawRate": 0.01, "steer": 0.002, "rearGripUse": 0.02 })


func test_suspension_preview_matches_ts() -> void:
	var fixture: Dictionary = _fixtures["suspension"]
	var b: Dictionary = fixture["baseline"]
	var solver := SuspensionSolver.new(b, SuspensionData.create_suspension(b))
	var samples: Array[Dictionary] = []
	for i in range(1, 121):
		solver.preview(1.0 / 60.0)
		if i % 30 == 0:
			samples.append(_snap(solver, i / 60.0))
	for i in range(1, 61):
		solver.preview(1.0 / 60.0, 3.0, 6.0, 0.3)
		if i % 15 == 0:
			samples.append(_snap(solver, 2.0 + i / 60.0))
	var expected: Array = fixture["samples"]
	for i in expected.size():
		for key in expected[i]:
			var tol := 1.0 if String(key).begins_with("load") else 1e-4
			_close("suspension t=%.2f %s" % [expected[i]["t"], key], samples[i][key], expected[i][key], tol)


func _snap(solver: SuspensionSolver, t: float) -> Dictionary:
	var out := { "t": t, "heave": solver.pose["heave"], "pitch": solver.pose["pitch"], "roll": solver.pose["roll"] }
	for i in 4:
		var c := solver.corners[i]
		out["q%d" % i] = c.compression
		out["load%d" % i] = c.wheel_load
		out["camber%d" % i] = c.camber
		out["steer%d" % i] = c.steering_angle
	return out
