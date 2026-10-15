class_name GameMenu
extends CanvasLayer
## Title screen and pause menu, lettered like a manga cover: a red sun, an extruded paper title
## and ink-boxed menu items. Both pause the tree; the page keeps rendering behind a paper wash.
## Esc / P / Start pauses. Keyboard, gamepad and mouse all drive the menu.

const CONTROLS := [
	["W  ↑", "THROTTLE"], ["S  ↓", "BRAKE"], ["A  D", "STEER"], ["SPACE", "HANDBRAKE"],
	["R", "RESET TO ROAD"], ["ENTER", "RESTART / REMATCH"], ["V", "CAMERA"], ["N", "DAY / NIGHT"],
	["T", "TUNE"], ["Y", "TIRES"], ["H", "TELEMETRY"], ["P", "AUTOPILOT"],
	["F", "REPLAY"], ["U", "CLEAN FEED (NO HUD)"], ["ESC", "PAUSE"],
]

## Set by tools (screenshots) to start straight on the road.
static var skip_title := false

var session: DriveSession
var time_attack: TimeAttack
var vs_battle: VsBattle
var music: MusicPlayer
var _replay_button: Button
var _wash := ColorRect.new()
var _title := Control.new()
var _pause := Control.new()
var _garage := Control.new()
var _settings := Control.new()
var _settings_first: Button
## Where BACK on the settings page goes: the title or the pause menu.
var _settings_return: Callable
var _bars: Array[InkBar] = []
var _opponents_button: Button
var _title_first: Button
var _pause_first: Button
## Garage page: the mode it leads into, its buttons per car id, and the spec card.
var _garage_mode: Label
var _garage_next: Callable
var _car_buttons := {}
var _card_drive: Label
var _card_name: Label
var _card_spec: Label
var _card_blurb: Label
var _preview: CarPreview
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
	_build_garage()
	_build_settings()
	GameSettings.apply_audio()
	if music:
		music.set_user_volume(GameSettings.value("music"))
	if not skip_title:
		GameSettings.apply_display()
	if skip_title:
		_close()
	else:
		open_title()


func _build_title() -> void:
	session.replay.restore_hud = func(): _set_play_hud(true)
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_title)
	var column := _column(_title)
	var art := TitleArt.new()
	art.custom_minimum_size = Vector2(640, 220)
	column.add_child(art)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 6)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(menu)
	_title_first = _button(menu, "VS BATTLE", func(): _open_garage("VS BATTLE", _start_vs))
	_button(menu, "SPECTATE", func(): _open_garage("SPECTATE", _start_spectate))
	_button(menu, "TIME ATTACK", _start_time_attack)
	_button(menu, "FREE DRIVE", func(): _open_garage("FREE DRIVE", _start_free_drive))
	_button(menu, "SETTINGS", func(): _open_settings(open_title))
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
	_replay_button = _button(left, "WATCH REPLAY", _toggle_replay)
	_value_button(left, func(): return "TUNE: " + ("DRIFT" if session.car.preset.ends_with("drift") else "STOCK"),
		func(): session.car.toggle_tune())
	_value_button(left, func(): return "TIRES: " + session.car.tire_product.to_upper(),
		func(): session.car.set_tire_product("street" if session.car.tire_product == "stock" else "stock"))
	_button(left, "SETTINGS", func(): _open_settings(open_pause))
	_button(left, "MAIN MENU", open_title)
	_button(left, "QUIT", get_tree().quit)

	# Controls card: a paper panel with an ink border, captions in Bangers.
	var card := _ink_card()
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


## The garage: pick the car, then the chosen mode starts with it.
func _build_garage() -> void:
	_garage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_garage)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 56)
	_garage.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	left.add_child(MangaType.label("GARAGE", 84))
	_garage_mode = _slab("", MangaType.RED)
	left.add_child(_garage_mode)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	left.add_child(gap)
	for spec in CarRoster.CARS:
		var b := _button(left, spec["name"], _pick_car.bind(spec["id"]))
		b.focus_entered.connect(_show_card.bind(spec))
		_car_buttons[spec["id"]] = b
	_opponents_button = _slider(left, func(): return "OPPONENTS", 1, GameSettings.MAX_OPPONENTS, "opponents", 400)
	_opponents_button.focus_entered.connect(func(): _show_card(session.car_spec))
	_button(left, "BACK", open_title)

	# Spec card: turntable in the car shader, a drivetrain stamp, name and blurb in Bangers.
	var card := _ink_card()
	row.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	card.add_child(body)
	_preview = CarPreview.new()
	_preview.custom_minimum_size = Vector2(520, 290)
	body.add_child(_preview)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	body.add_child(head)
	_card_drive = _slab("", MangaType.INK)
	_card_drive.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_card_drive)
	_card_name = Label.new()
	MangaType.ink(_card_name, 44)
	head.add_child(_card_name)
	_card_spec = Label.new()
	MangaType.ink(_card_spec, 30, MangaType.caption())
	body.add_child(_card_spec)
	_card_blurb = Label.new()
	MangaType.ink(_card_blurb, 24, MangaType.caption())
	_card_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_blurb.custom_minimum_size.x = 520
	body.add_child(_card_blurb)
	var hint := MangaType.label("↑ ↓  SELECT     ENTER  DRIVE     ESC  BACK", 20, MangaType.caption())
	hint.add_theme_color_override("font_color", MangaType.INK)
	hint.remove_theme_constant_override("outline_size")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_top = -64
	hint.offset_bottom = -30
	_garage.add_child(hint)


## Paper panel, ink border, hard ink drop shadow: a manga info box.
func _ink_card() -> PanelContainer:
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
	return card


## Paper Bangers lettering on a solid slab, like a caption stamp.
func _slab(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	MangaType.ink(l, 30, MangaType.caption())
	l.add_theme_color_override("font_color", MangaType.PAPER)
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", box)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


## Settings: sound sliders on the left, display and view toggles on the right. Saved as they change.
func _build_settings() -> void:
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_settings)
	var column := _column(_settings)
	column.add_child(MangaType.label("SETTINGS", 84))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	column.add_child(row)
	var sound := VBoxContainer.new()
	sound.add_theme_constant_override("separation", 6)
	row.add_child(sound)
	sound.add_child(_slab("SOUND", MangaType.RED))
	_settings_first = _slider(sound, func(): return "MASTER", 0, 10, "master")
	_slider(sound, func(): return "MUSIC", 0, 10, "music")
	_slider(sound, func(): return "ENGINE", 0, 10, "engine")
	_slider(sound, func(): return "EFFECTS", 0, 10, "effects")
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 6)
	row.add_child(view)
	view.add_child(_slab("DISPLAY", MangaType.RED))
	_value_button(view, func(): return "FULLSCREEN: " + ("ON" if GameSettings.value("fullscreen") else "OFF"),
		func(): _toggle_setting("fullscreen"))
	_value_button(view, func(): return "VSYNC: " + ("ON" if GameSettings.value("vsync") else "OFF"),
		func(): _toggle_setting("vsync"))
	_value_button(view, _camera_text, _cycle_camera)
	_value_button(view, _time_text, _toggle_time)
	var back := _button(column, "BACK", func(): _settings_return.call())
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var hint := MangaType.label("← →  ADJUST     ENTER  CHANGE     ESC  BACK", 20, MangaType.caption())
	hint.add_theme_color_override("font_color", MangaType.INK)
	hint.remove_theme_constant_override("outline_size")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _open_settings(back_to: Callable) -> void:
	_settings_return = back_to
	_show(_settings, _settings_first)


func _toggle_setting(key: String) -> void:
	GameSettings.set_value(key, not GameSettings.value(key))
	GameSettings.apply_display()


## A setting with an ink-box gauge on the right: ← → adjust, Enter/click steps up and wraps.
func _slider(parent: Control, text: Callable, lo: int, hi: int, key: String, width := 560) -> Button:
	var change := func(v: int) -> void:
		GameSettings.set_value(key, v)
		_apply_setting(key)
		_refresh()
	var b := _value_button(parent, text, func():
		var v: int = GameSettings.value(key)
		change.call(lo if v >= hi else v + 1))
	b.custom_minimum_size.x = width
	var bar := InkBar.new()
	bar.button = b
	bar.lo = lo
	bar.hi = hi
	bar.key = key
	b.add_child(bar)
	_bars.append(bar)
	b.focus_entered.connect(bar.queue_redraw)
	b.focus_exited.connect(bar.queue_redraw)
	b.gui_input.connect(func(e: InputEvent) -> void:
		var step := -1 if e.is_action_pressed("ui_left") else (1 if e.is_action_pressed("ui_right") else 0)
		if step != 0:
			b.accept_event()
			change.call(clampi(int(GameSettings.value(key)) + step, lo, hi)))
	return b


func _apply_setting(key: String) -> void:
	if key == "music":
		if music:
			music.set_user_volume(GameSettings.value("music"))
	elif key in GameSettings.BUSES:
		GameSettings.apply_audio()


func _open_garage(mode: String, next: Callable) -> void:
	_opponents_button.visible = mode == "VS BATTLE"
	_garage_mode.text = mode
	_garage_next = next
	_show(_garage, _car_buttons[session.car_spec["id"]])
	_show_card(session.car_spec)


func _show_card(spec: Dictionary) -> void:
	_card_drive.text = spec["drive"]
	_card_name.text = spec["name"]
	_card_spec.text = spec["spec"]
	_card_blurb.text = spec["blurb"]
	_preview.show_car(spec["model"])


func _pick_car(id: String) -> void:
	session.set_car(id)
	_garage_next.call()


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
	for bar in _bars:
		bar.queue_redraw()


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
	session.replay.stop()
	session.set_autopilot(false)
	_show(_title, _title_first)
	_set_play_hud(false)
	if music:
		music.duck(false)
		music.stop_music()


func open_pause() -> void:
	_restart_button.visible = time_attack.active or vs_battle.active
	_replay_button.visible = session.replay.playing or session.replay.can_play()
	_replay_button.text = "EXIT REPLAY" if session.replay.playing else "WATCH REPLAY"
	_show(_pause, _pause_first)
	if music:
		music.duck(true)


func _show(screen: Control, first: Button) -> void:
	_title.visible = screen == _title
	_pause.visible = screen == _pause
	_garage.visible = screen == _garage
	_settings.visible = screen == _settings
	_wash.visible = true
	_refresh()
	get_tree().paused = true
	_mute_car(true)
	first.grab_focus.call_deferred()


func _close() -> void:
	_title.visible = false
	_pause.visible = false
	_garage.visible = false
	_settings.visible = false
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
	_leave_watch()
	vs_battle.opponents = GameSettings.value("opponents")
	time_attack.free_drive()
	_close()
	vs_battle.start()


func _start_time_attack() -> void:
	_leave_watch()
	vs_battle.stop()
	_close()
	time_attack.restart(true)


func _start_free_drive() -> void:
	_leave_watch()
	vs_battle.stop()
	time_attack.free_drive()
	_close()
	music.stop_music()


func _restart_mode() -> void:
	session.replay.stop()
	_close()
	if vs_battle.active:
		vs_battle.start()
	else:
		time_attack.restart()


## Out of any replay, autopilot and cinematic view before a mode starts.
func _leave_watch() -> void:
	session.replay.stop()
	session.set_autopilot(false)
	if session.camera.mode == ChaseCamera.Mode.CINEMATIC:
		session.camera.mode = ChaseCamera.Mode.CHASE


## A VS battle you watch: your car on autopilot, the cinematic camera directing.
func _start_spectate() -> void:
	_start_vs()
	session.camera.mode = ChaseCamera.Mode.CINEMATIC
	# The grid placement lands on the next physics step; take the lane from there.
	await get_tree().physics_frame
	await get_tree().physics_frame
	session.set_autopilot(true)


func _toggle_replay() -> void:
	_close()
	if session.replay.playing:
		session.replay.stop()
	else:
		session.replay.start()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if _pause.visible:
		_close()
	elif _garage.visible:
		open_title()
	elif _settings.visible:
		_settings_return.call()
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


## The garage turntable: the car in its own little world, shaded by MangaArt like on the road,
## turning slowly on the paper card. Keeps spinning while the tree is paused.
class CarPreview extends SubViewportContainer:
	var _viewport := SubViewport.new()
	var _pivot := Node3D.new()
	var _path := ""

	func _ready() -> void:
		stretch = true
		process_mode = Node.PROCESS_MODE_ALWAYS
		_viewport.own_world_3d = true
		_viewport.transparent_bg = true
		_viewport.msaa_3d = Viewport.MSAA_4X
		add_child(_viewport)
		_viewport.add_child(_pivot)
		var cam := Camera3D.new()
		cam.fov = 26.0
		cam.transform = Transform3D(Basis(), Vector3(4.7, 1.9, 5.8)).looking_at(Vector3(0, 0.5, 0))
		_viewport.add_child(cam)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55, 35, 0)
		_viewport.add_child(sun)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = MangaType.PAPER
		env.environment.ambient_light_energy = 0.6
		_viewport.add_child(env)
		_pivot.rotation.y = -0.6

	func show_car(path: String) -> void:
		if path == _path:
			return
		_path = path
		for c in _pivot.get_children():
			c.queue_free()
		var model: Node3D = (load(path) as PackedScene).instantiate()
		MangaArt.apply_car(model, CarVisual.PLAYER_PAINT)
		_pivot.add_child(model)

	func _process(delta: float) -> void:
		_pivot.rotate_y(delta * 0.5)


## A setting's level as a row of slanted ink boxes, filled up to the value. Paper on the lit
## (focused) button, ink otherwise.
class InkBar extends Control:
	const BOX := Vector2(18, 22)
	const GAP := 6.0
	var button: Button
	var lo := 0
	var hi := 10
	var key := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := (hi - (0 if lo == 0 else lo - 1)) * (BOX.x + GAP)
		anchor_left = 1.0
		anchor_right = 1.0
		anchor_top = 0.5
		anchor_bottom = 0.5
		offset_left = -w - 22.0
		offset_right = -22.0
		offset_top = -BOX.y / 2.0
		offset_bottom = BOX.y / 2.0

	func _draw() -> void:
		var lit := button.has_focus()
		var ink := MangaType.PAPER if lit else MangaType.INK
		var first := 0 if lo == 0 else lo - 1
		var v: int = GameSettings.value(key)
		for i in range(first, hi):
			var x := (i - first) * (BOX.x + GAP)
			var slant := 5.0
			var pts := PackedVector2Array([Vector2(x + slant, 0), Vector2(x + BOX.x + slant, 0),
				Vector2(x + BOX.x - slant, BOX.y), Vector2(x - slant, BOX.y)])
			if i < v:
				draw_colored_polygon(pts, ink)
			else:
				pts.append(pts[0])
				draw_polyline(pts, ink, 3.0)
