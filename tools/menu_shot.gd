extends SceneTree
## Menu screenshots (needs a window, not --headless): opens a menu page on the touge scene,
## moves the focus a few steps and saves a PNG. `godot --path . -s res://tools/menu_shot.gd -- <out.png> [page]`
## Pages: tuning (default), settings, garage, story.

var _scene: Node
var _out := ""
var _page := "tuning"
var _frame := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://menu.png"
	_page = args[1] if args.size() > 1 else "tuning"
	# The shot nudges sliders: never the player's setups.
	CarSetup.path = "user://menu_shot_setups.json"
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _process(_delta: float) -> bool:
	_frame += 1
	var menu: GameMenu = _scene.menu
	if _frame == 60:
		match _page:
			"settings":
				menu._open_settings(menu.open_title)
			"garage":
				menu._open_garage("VS BATTLE", menu.open_title)
			"story":
				menu._open_story()
			_:
				menu._open_tuning(menu.open_title)
	elif _frame in [80, 90, 100]:
		_press("ui_down")
	elif _frame in [110, 120]:
		_press("ui_right")
	elif _frame == 150:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		quit(0)
	return false


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
