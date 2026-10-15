class_name GameMenu
extends CanvasLayer
## Title screen and pause menu, lettered like a manga cover: a red sun, an extruded paper title
## and ink-boxed menu items. Both pause the tree; the page keeps rendering behind a paper wash.
## Esc / P / Start pauses. Keyboard, gamepad and mouse all drive the menu.

const CONTROLS := [
	["W  ↑", "THROTTLE"], ["S  ↓", "BRAKE"], ["A  D", "STEER"], ["SPACE", "HANDBRAKE"],
	["R", "RESET TO ROAD"], ["ENTER", "RESTART / REMATCH"], ["V", "CAMERA"], ["N", "DAY / NIGHT"],
	["T", "TUNE"], ["Y", "TIRES"], ["H", "TELEMETRY"], ["ESC", "PAUSE"],
]

## Set by tools (screenshots) to start straight on the road.
static var skip_title := false

var session: DriveSession
var time_attack: TimeAttack
var vs_battle: VsBattle
var music: MusicPlayer
var _wash := ColorRect.new()
var _title := Control.new()
var _pause := Control.new()
var _title_first: Button
var _pause_first: Button
var _restart_button: Button
var _value_buttons: Array = [] # [Button, Callable -> String]


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		for key in [KEY_ESCAPE, KEY_P]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event("pause", e)
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_START
		InputMap.action_add_event("pause", pad)
	# The day/night fade runs from the menu while the tree is paused.
	session.day_night.process_mode = Node.PROCESS_MODE_ALWAYS

	_wash.color = Color(MangaType.PAPER, 0.78)
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_wash)
	_build_title()
	_build_pause()
	if skip_title:
		_close()
	else:
		open_title()


func _build_title() -> void:
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_title)
	var column := _column(_title)
	var art := TitleArt.new()
	art.custom_minimum_size = Vector2(640, 270)
	column.add_child(art)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 6)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(menu)
	_title_first = _button(menu, "VS BATTLE", _start_vs)
	_button(menu, "TIME ATTACK", _start_time_attack)
	_button(menu, "FREE DRIVE", _start_free_drive)
	_value_button(menu, _camera_text, _cycle_camera)
	_value_button(menu, _time_text, _toggle_time)
	_button(menu, "QUIT", get_tree().quit)
	var hint := MangaType.label("↑ ↓  SELECT     ENTER  GO", 20, MangaType.caption())
	hint.add_theme_color_override("font_color", MangaType.INK)
	hint.remove_theme_constant_override("outline_size")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _build_pause() -> void:
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pause)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 64)
	_pause.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var heading := MangaType.label("PAUSE", 84)
	left.add_child(heading)
	_pause_first = _button(left, "RESUME", _close)
	_restart_button = _button(left, "RESTART", _restart_mode)
	_value_button(left, _camera_text, _cycle_camera)
	_value_button(left, _time_text, _toggle_time)
	_value_button(left, func(): return "TUNE: " + ("DRIFT" if session.car.preset.ends_with("drift") else "STOCK"),
		func(): session.car.toggle_tune())
	_value_button(left, func(): return "TIRES: " + session.car.tire_product.to_upper(),
		func(): session.car.set_tire_product("street" if session.car.tire_product == "stock" else "stock"))
	_button(left, "MAIN MENU", open_title)
	_button(left, "QUIT", get_tree().quit)

	# Controls card: a paper panel with an ink border, captions in Bangers.
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = MangaType.PAPER
	box.border_color = MangaType.INK
	box.set_border_width_all(4)
	box.set_content_margin_all(22)
	box.shadow_color = MangaType.INK
	box.shadow_size = 1
	box.shadow_offset = Vector2(8, 8)
	card.add_theme_stylebox_override("panel", box)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(card)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 2)
	card.add_child(grid)
	var head := Label.new()
	head.text = "CONTROLS"
	MangaType.ink(head, 24)
	grid.add_child(head)
	grid.add_child(Control.new())
	for pair in CONTROLS:
		var key := Label.new()
		key.text = pair[0]
		MangaType.ink(key, 24, MangaType.caption())
		grid.add_child(key)
		var what := Label.new()
		what.text = pair[1]
		MangaType.ink(what, 24, MangaType.caption())
		grid.add_child(what)


func _column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	parent.add_child(column)
	return column


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.x = 340
	MangaType.ink(b, 28)
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(MangaType.PAPER, 0.0)
	plain.set_content_margin_all(6)
	plain.content_margin_left = 18
	var lit := StyleBoxFlat.new()
	lit.bg_color = MangaType.INK
	lit.set_content_margin_all(6)
	lit.content_margin_left = 18
	lit.shadow_color = MangaType.INK
	lit.shadow_size = 1
	lit.shadow_offset = Vector2(7, 7)
	for state in ["normal", "disabled"]:
		b.add_theme_stylebox_override(state, plain)
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(state, lit)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, MangaType.PAPER)
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _value_button(parent: Control, text: Callable, action: Callable) -> Button:
	var b := _button(parent, text.call(), func(): action.call(); _refresh())
	_value_buttons.append([b, text])
	return b


func _refresh() -> void:
	for pair in _value_buttons:
		(pair[0] as Button).text = (pair[1] as Callable).call()


func _camera_text() -> String:
	return "CAMERA: " + ChaseCamera.MODE_NAMES[session.camera.mode]


func _cycle_camera() -> void:
	session.camera.mode = ((session.camera.mode + 1) % ChaseCamera.Mode.size()) as ChaseCamera.Mode


func _time_text() -> String:
	# The switch fades, so read where it is heading rather than where it is.
	return "TIME: " + ("NIGHT" if session.day_night.heading_to_night() else "DAY")


func _toggle_time() -> void:
	session.day_night.toggle()


func open_title() -> void:
	_show(_title, _title_first)
	_set_play_hud(false)
	if music:
		music.duck(false)
		music.play_track(&"menu")


func open_pause() -> void:
	_restart_button.visible = time_attack.active or vs_battle.active
	_show(_pause, _pause_first)
	if music:
		music.duck(true)


func _show(screen: Control, first: Button) -> void:
	_title.visible = screen == _title
	_pause.visible = screen == _pause
	_wash.visible = true
	_refresh()
	get_tree().paused = true
	_mute_car(true)
	first.grab_focus.call_deferred()


func _close() -> void:
	_title.visible = false
	_pause.visible = false
	_wash.visible = false
	get_viewport().gui_release_focus()
	_set_play_hud(true)
	get_tree().paused = false
	_mute_car(false)
	if music:
		music.duck(false)


## Car sounds stop while paused; the music keeps playing (ducked).
func _mute_car(on: bool) -> void:
	for bus in ["Engine", "EngineOff", "Tires", "Fx"]:
		var i := AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_mute(i, on)


func _set_play_hud(on: bool) -> void:
	session.hud.visible = on
	session.day_night.visible = on
	session.gauges.visible = on
	time_attack.hud.visible = on and time_attack.active and time_attack.run != null
	vs_battle.hud.visible = on and vs_battle.active and vs_battle.run != null


func _start_vs() -> void:
	time_attack.free_drive()
	_close()
	vs_battle.start()


func _start_time_attack() -> void:
	vs_battle.stop()
	_close()
	music.play_track(&"race_alt")
	time_attack.restart(true)


func _start_free_drive() -> void:
	vs_battle.stop()
	time_attack.free_drive()
	_close()
	music.play_track(&"menu")


func _restart_mode() -> void:
	_close()
	if vs_battle.active:
		vs_battle.start()
	else:
		time_attack.restart()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if _pause.visible:
		_close()
	elif not _title.visible:
		open_pause()


## The cover art: a red sun with ink sparkles, the title in extruded paper letters over it.
class TitleArt extends Control:
	func _ready() -> void:
		var title := MangaType.label("PANG DAILY", 104)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.set_anchors_preset(Control.PRESET_CENTER)
		title.grow_horizontal = Control.GROW_DIRECTION_BOTH
		title.grow_vertical = Control.GROW_DIRECTION_BOTH
		title.position.y -= 18
		add_child(title)
		var sub := MangaType.label("TOUGE  ·  MOUNTAIN PASS", 30, MangaType.caption())
		sub.add_theme_color_override("font_color", MangaType.INK)
		sub.add_theme_color_override("font_outline_color", MangaType.PAPER)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
		sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
		sub.position.y -= 20
		add_child(sub)

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, size.y * 0.46, MangaType.RED)
		for s in [[Vector2(-0.40, -0.26), 16.0], [Vector2(-0.36, -0.17), 8.0], [Vector2(0.40, -0.22), 14.0],
				[Vector2(0.45, -0.30), 7.0], [Vector2(-0.42, 0.28), 13.0], [Vector2(0.38, 0.30), 15.0], [Vector2(0.44, 0.22), 7.0]]:
			_sparkle(c + Vector2(s[0].x * size.x, s[0].y * size.y), s[1])

	func _sparkle(at: Vector2, r: float) -> void:
		var points := PackedVector2Array()
		for i in 8:
			var a := i * PI / 4.0
			var d := r if i % 2 == 0 else r * 0.22
			points.append(at + Vector2(sin(a), -cos(a)) * d)
		draw_colored_polygon(points, MangaType.INK)
