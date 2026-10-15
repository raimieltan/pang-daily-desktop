extends SceneTree
## Headless smoke drive: `godot --headless --path . -s res://tests/smoke_drive.gd`
## Loads the drive test, scripts the pedals and prints telemetry once a second.

var _scene
var _t := 0.0


func _initialize() -> void:
	_scene = load("res://scenes/drive_test.tscn").instantiate()
	root.add_child(_scene)


func _scripted() -> VehicleTypes.DriverInput:
	# 0–2 s parked, 2–10 s full throttle, 10–13 s right turn, 13–16 s brake.
	if _t < 2.0: return VehicleTypes.DriverInput.make(0, 0, 0)
	if _t < 10.0: return VehicleTypes.DriverInput.make(1, 0, 0)
	if _t < 13.0: return VehicleTypes.DriverInput.make(0.4, 0, 0.5, 0, "keyboard")
	return VehicleTypes.DriverInput.make(0, 1, 0)


func _physics_process(delta: float) -> bool:
	_t += delta
	var car: CarBody = _scene.car
	if car.input_source != _scripted:
		car.input_source = _scripted
	if fmod(_t, 1.0) < delta:
		var m := car.model
		print("t=%5.2f  pos=(%6.2f %5.2f %7.2f)  kmh=%6.1f  gear=%d rpm=%4.0f  yaw=%+5.1f°/s  loads=%s  q=%s  grounded=%s" % [
			_t, car.global_position.x, car.global_position.y, car.global_position.z, car.speed_kmh(), m.mechanics.gear,
			m.mechanics.engine_rpm, rad_to_deg(m.state.yaw_rate),
			[roundi(car.solver.corners[0].wheel_load), roundi(car.solver.corners[1].wheel_load), roundi(car.solver.corners[2].wheel_load), roundi(car.solver.corners[3].wheel_load)],
			[snappedf(car.solver.corners[0].compression, 0.001), snappedf(car.solver.corners[2].compression, 0.001)],
			car.contact.wheels])
	return _t > 16.0
