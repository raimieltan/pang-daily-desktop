extends SceneTree
## Screenshots of story mode's garage and board pages (needs a window, not --headless): the shop,
## tuning and ledger tabs and Kapitan's board, at a beat, on a throwaway progress state.
## `godot --path . -s res://tools/garage_shot.gd -- <out_dir> [beat_id]`

var _out := ""
var _garage: StoryGarage
var _t := 0.0
var _step := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://garage_shots"
	DirAccess.make_dir_recursive_absolute(_out)
	StoryMode.reset_progress()
	StoryMode.beat = StoryScript.index_of(args[1] if args.size() > 1 else "s09b1")
	StoryMode.earn(14500)
	StoryMode.commitments.append(["KUYA BEN'S LENS", 6000])
	CarParts.fit(StoryMode.car(), "exhaust")
	var bg := ColorRect.new()
	bg.color = Color(0.3, 0.3, 0.3)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_garage = StoryGarage.new()
	root.add_child(_garage)


func _process(delta: float) -> bool:
	_t += delta
	if _t < 0.6:
		return false
	_t = 0.0
	match _step:
		0:
			_garage.open_garage("shop")
		1:
			_shot("shop")
			_garage._switch("tune")
		2:
			_shot("tune")
			_garage._switch("ledger")
		3:
			_shot("ledger")
			_garage._leave({})
			var b: Dictionary = StoryScript.BEATS[StoryMode.beat]
			_garage.open_board(StoryBoard.events(b) if b["type"] == "roam" else [])
		4:
			_shot("board")
			quit(0)
	_step += 1
	return false


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
