extends SceneTree
## Renders screenshots of a scene for visual checks (needs a window, not --headless):
## `godot --path . -s res://tools/screenshot.gd -- <scene> <out_dir> [drive_seconds]`
## Shots: the chase camera at spawn, after driving (scripted throttle), and a high overview.

var _scene_path := "res://scenes/touge.tscn"
var _out := "user://shots"
var _drive_seconds := 6.0
var _scene
var _t := 0.0
var _stage := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _scene_path = args[0]
	if args.size() > 1: _out = args[1]
	if args.size() > 2: _drive_seconds = float(args[2])
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1280, 720)
	_scene = load(_scene_path).instantiate()
	root.add_child(_scene)


func _drive() -> VehicleTypes.DriverInput:
	return VehicleTypes.DriverInput.make(0.8, 0.0, 0.0)


func _process(delta: float) -> bool:
	_t += delta
	var session: DriveSession = _scene.session
	match _stage:
		0:
			if _t > 2.0:
				_shot("1_spawn")
				session.car.input_source = _drive
				_stage = 1
		1:
			if _t > 2.0 + _drive_seconds:
				_shot("2_driving")
				var cam := Camera3D.new()
				_scene.add_child(cam)
				var p := session.car.global_position
				cam.global_position = p + Vector3(120, 260, 260)
				cam.look_at(p + Vector3(0, -60, -120))
				cam.far = 4000
				var env: Environment = _scene.get_node("WorldEnvironment").environment if _scene.has_node("WorldEnvironment") else null
				if env: env.fog_enabled = false
				cam.current = true
				_stage = 2
				_t = 100.0
		2:
			if _t > 101.0:
				_shot("3_overview")
				return true
	return false


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("saved ", path)
