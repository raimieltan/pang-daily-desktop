class_name CameraPicker
extends CanvasLayer
## The camera views as a strip of panels at the bottom of the page. Pops up on V (or whenever the
## view changes) with the current one inked in, then fades out.

const SHOW_SECONDS := 1.8

var camera: ChaseCamera
var _root := VBoxContainer.new()
var _chips: Array[Label] = []
var _tween: Tween


func _ready() -> void:
	layer = 12
	_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.position.y = -36
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_theme_constant_override("separation", 6)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var title := MangaType.label("CAMERA  [V]", 22, false, MangaType.caption())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(row)
	for name in ChaseCamera.MODE_NAMES:
		var chip := Label.new()
		chip.text = name
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.custom_minimum_size.x = 120
		row.add_child(chip)
		_chips.append(chip)
	_root.modulate.a = 0.0
	camera.mode_changed.connect(func(_m): pop())
	_paint()


func pop() -> void:
	_paint()
	if _tween:
		_tween.kill()
	_root.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(_root, "modulate:a", 0.0, 0.4)


func _paint() -> void:
	for i in _chips.size():
		var chip := _chips[i]
		var on := i == int(camera.mode)
		var box := StyleBoxFlat.new()
		box.bg_color = MangaType.INK if on else MangaType.PAPER
		box.border_color = MangaType.INK
		box.set_border_width_all(3)
		box.set_content_margin_all(8)
		if on:
			box.shadow_color = MangaType.RED
			box.shadow_size = 1
			box.shadow_offset = Vector2(5, 5)
		chip.add_theme_stylebox_override("normal", box)
		MangaType.ink(chip, 20)
		chip.add_theme_color_override("font_color", MangaType.PAPER if on else MangaType.INK)
