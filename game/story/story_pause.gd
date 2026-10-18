class_name StoryPause
extends CanvasLayer
## The story's pause menu on the stages without the game menu (the barangay, the rooms, the paper
## pages; Pass 1 has GameMenu's): Esc / Start pauses, RESUME or QUIT TO TITLE (progress is saved
## at every beat). The garage and the board take Esc first while they are open.

var _page := VBoxContainer.new()
var _first: Button
var _where: Label
## The car buses this pause muted (a page may have muted some already; those stay as they were).
var _muted: Array = []


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var wash := ColorRect.new()
	wash.color = Color(MangaType.PAPER, 0.85)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wash)
	_page.set_anchors_preset(Control.PRESET_CENTER)
	_page.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_page.grow_vertical = Control.GROW_DIRECTION_BOTH
	_page.add_theme_constant_override("separation", 14)
	add_child(_page)
	_page.add_child(MangaType.label("PAUSED", 84))
	_where = MangaType.label("", 24, MangaType.caption())
	_where.add_theme_color_override("font_color", MangaType.INK)
	_where.remove_theme_constant_override("outline_size")
	_page.add_child(_where)
	_first = _button("RESUME", close)
	_button("QUIT TO TITLE", func():
		close()
		StoryMode.quit_to_title(get_tree()))
	var note := MangaType.label("PROGRESS IS SAVED AT EVERY SCENE.", 20, MangaType.caption())
	note.add_theme_color_override("font_color", MangaType.INK)
	note.remove_theme_constant_override("outline_size")
	_page.add_child(note)


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("hub_menu") or (InputMap.has_action("pause") and event.is_action_pressed("pause"))):
		return
	get_viewport().set_input_as_handled()
	if visible:
		close()
	else:
		open()


func open() -> void:
	var b := StoryMode.current()
	_where.text = str(b.get("title", b.get("place", b.get("prompt", ""))))
	visible = true
	get_tree().paused = true
	_muted = StoryDialogue._mute_car(true)
	_first.grab_focus.call_deferred()


func close() -> void:
	visible = false
	get_viewport().gui_release_focus()
	get_tree().paused = false
	for i in _muted:
		AudioServer.set_bus_mute(i, false)
	_muted = []


func _button(text: String, action: Callable) -> Button:
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
	b.add_theme_stylebox_override("normal", plain)
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(state, lit)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, MangaType.PAPER)
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(action)
	_page.add_child(b)
	return b
