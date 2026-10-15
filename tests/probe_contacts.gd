extends SceneTree
## Probe: steer into the start-straight guardrail and log wall contacts.
var _scene
var _t := 0.0
var _count := 0
var _max_slide := 0.0
var _max_dv := 0.0
func _initialize() -> void:
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)
func _input_now() -> VehicleTypes.DriverInput:
	if _t < 1.5: return VehicleTypes.DriverInput.make(0, 0, 0)
	if _t < 7.0: return VehicleTypes.DriverInput.make(1, 0, 0)
	return VehicleTypes.DriverInput.make(1, 0, -0.5, 0, "ai")
func _on_contact(_p: Vector3, _n: Vector3, dv: float, slide: float) -> void:
	_count += 1
	_max_slide = maxf(_max_slide, slide)
	_max_dv = maxf(_max_dv, dv)
func _physics_process(delta: float) -> bool:
	var car: CarBody = _scene.car
	if car.input_source != _input_now:
		car.input_source = _input_now
		car.wall_contact.connect(_on_contact)
	_t += delta
	if fmod(_t, 0.5) < delta and _t > 7.0:
		var i: int = _scene.track.nearest_index(car.global_position)
		print("t=%.1f lateral=%.2f contacts=%d (raw %d) max slide %.1f dv %.2f" % [_t, _scene.track.lateral_offset(car.global_position, i), _count, car.get_contact_count(), _max_slide, _max_dv])
	return _t > 10.0
