extends SceneTree
## Hub screenshots (needs a window, not --headless): Kyo from across the street, the talyer, the
## chase camera at Kyo, and Kyo at night. Writes PNGs to the directory after `--`.
## `godot --path . -s res://tools/hub_shot.gd -- <out_dir>`

const SHOTS := [
	# name, eye (hub x, z, height), look at (hub x, z, height), night
	["kyo_street", Vector3(118, 88, 1.7), Vector3(145, 102, 4.5), false],
	["kyo_front", Vector3(116, 101, 2.0), Vector3(145, 101, 4.0), false],
	["talyer", Vector3(22, 128, 1.8), Vector3(26, 158, 2.0), false],
	["chase", Vector3.ZERO, Vector3.ZERO, false],
	["kyo_night", Vector3(118, 88, 1.7), Vector3(145, 102, 4.5), true],
	["overview", Vector3(40, -60, 120), Vector3(40, 80, 0), false],
]

var _hub: Node3D
var _cam: Camera3D
var _out := ""
var _frame := 0
var _shot := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://hub_shots"
	DirAccess.make_dir_recursive_absolute(_out)
	_hub = load("res://scenes/hub.tscn").instantiate()
	root.add_child(_hub)
	current_scene = _hub
	_cam = Camera3D.new()
	_cam.fov = 60
	_hub.add_child(_cam)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 90:
		return false
	var spec: Array = SHOTS[_shot]
	var phase := (_frame - 90) % 40
	if phase == 0:
		MangaArt.set_night(spec[3])
		if spec[0] == "chase":
			_hub.session.camera.current = true
		else:
			var eye: Vector3 = spec[1]
			var at: Vector3 = spec[2]
			_cam.position = HubLayout.pos(eye.x, eye.y, eye.z)
			_cam.look_at(HubLayout.pos(at.x, at.y, at.z))
			_cam.current = true
	elif phase == 39:
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [_out, spec[0]]
		img.save_png(path)
		print("saved ", path)
		_shot += 1
		if _shot >= SHOTS.size():
			quit(0)
	return false
