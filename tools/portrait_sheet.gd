extends SceneTree
## Every story portrait on one sheet (needs a window): `godot --path . -s res://tools/portrait_sheet.gd -- <out.png>`

var _frames := 0


func _initialize() -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.position = Vector2(16, 16)
	root.add_child(grid)
	for who in StoryPortrait.LOOKS:
		var p := StoryPortrait.new()
		p.custom_minimum_size = Vector2(200, 200)
		grid.add_child(p)
		p.show_speaker(who)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		var args := OS.get_cmdline_user_args()
		root.get_texture().get_image().save_png(args[0] if args.size() > 0 else "user://portraits.png")
		return true
	return false
