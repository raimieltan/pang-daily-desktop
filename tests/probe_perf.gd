extends SceneTree
## Where does a physics step go? Times the sim pieces inside CarBody over 600 steps of driving.
var _scene
var _n := 0
var _t := {"suspension": 0, "model": 0, "total": 0}
func _initialize() -> void:
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)
func _physics_process(_d: float) -> bool:
	_n += 1
	if _n < 400: return false
	var car: CarBody = _scene.car
	var solver := car.solver
	var model := car.model
	var input := VehicleTypes.DriverInput.make(1, 0, 0.1)
	var si := SuspensionSolver.StepInput.new()
	for i in 4:
		si.mounts[i] = 0.0; si.roads[i] = -0.3
	var a := Time.get_ticks_usec()
	solver.step(1.0 / 120.0, si)
	var b := Time.get_ticks_usec()
	model.step(1.0 / 120.0, input, car.contact)
	var c := Time.get_ticks_usec()
	_t["suspension"] += b - a
	_t["model"] += c - b
	if _n >= 700:
		print("per step: suspension %.3f ms, handling model %.3f ms (over 300 steps)" % [_t["suspension"] / 300000.0, _t["model"] / 300000.0])
		return true
	return false
