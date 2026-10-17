class_name StoryDialogue
extends CanvasLayer
## The story's page furniture, in the manga lettering of docs/ART_DIRECTION.md §7: letterbox bars,
## a place/time caption stamp, speech panels with the speaker's name on an ink slab, ink narration
## boxes, a phone feed for the group chat, act cards, hard black cuts, and the sound motifs.
## Enter / Space / E / click advances (the first press finishes the line being lettered).

signal advanced

const CHARS_PER_SECOND := 70.0
const SFX := {
	"wrench": preload("res://assets/audio/story/wrench.wav"),
	"shutter": preload("res://assets/audio/story/shutter.wav"),
	"phone_buzz": preload("res://assets/audio/story/phone_buzz.wav"),
	"pulse": preload("res://assets/audio/story/pulse.wav"),
	"wiper": preload("res://assets/audio/story/wiper.wav"),
	"impact": preload("res://assets/audio/impact/impactMetal_heavy_000.ogg"),
}

## Auto-advance after this many seconds per line (tests and probes); 0 waits for the player.
static var auto_advance := 0.0

var _top: ColorRect
var _bottom: ColorRect
var _caption: Label
var _panel: PanelContainer
var _name: Label
var _text: Label
var _more: Label
var _phone: PanelContainer
var _feed: VBoxContainer
var _phone_title: Label
var _black: ColorRect
var _white: ColorRect
var _card: Control
var _card_act: Label
var _card_title: Label
var _card_sub: Label
var _subtitle: Label
var _subtitle_time := 0.0
var _typing := false
var _waiting := false
var _shown := 0.0
var _tokens := {}


func _ready() -> void:
	layer = 15
	_top = _bar(Control.PRESET_TOP_WIDE)
	_bottom = _bar(Control.PRESET_BOTTOM_WIDE)
	_caption = Label.new()
	MangaType.ink(_caption, 26, MangaType.caption())
	_caption.add_theme_color_override("font_color", MangaType.PAPER)
	var stamp := StyleBoxFlat.new()
	stamp.bg_color = MangaType.RED
	stamp.content_margin_left = 16
	stamp.content_margin_right = 16
	stamp.content_margin_top = 2
	stamp.content_margin_bottom = 2
	_caption.add_theme_stylebox_override("normal", stamp)
	_caption.position = Vector2(40, 96)
	_caption.visible = false
	add_child(_caption)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_top = -250
	_panel.offset_bottom = -110
	_panel.offset_left = -560
	_panel.offset_right = 560
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	_name = Label.new()
	MangaType.ink(_name, 26, MangaType.caption())
	_name.add_theme_color_override("font_color", MangaType.PAPER)
	var slab := StyleBoxFlat.new()
	slab.bg_color = MangaType.INK
	slab.content_margin_left = 12
	slab.content_margin_right = 12
	_name.add_theme_stylebox_override("normal", slab)
	_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_name)
	_text = Label.new()
	MangaType.ink(_text, 30, MangaType.caption())
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(1060, 70)
	column.add_child(_text)
	_more = Label.new()
	MangaType.ink(_more, 22, MangaType.caption())
	_more.text = "▼"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_more)
	_panel.visible = false

	_phone = PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = MangaType.PAPER
	frame.border_color = MangaType.INK
	frame.set_border_width_all(10)
	frame.set_corner_radius_all(36)
	frame.set_content_margin_all(20)
	frame.shadow_color = MangaType.INK
	frame.shadow_size = 1
	frame.shadow_offset = Vector2(10, 10)
	_phone.add_theme_stylebox_override("panel", frame)
	_phone.set_anchors_preset(Control.PRESET_CENTER)
	_phone.custom_minimum_size = Vector2(500, 580)
	_phone.offset_left = -250
	_phone.offset_right = 250
	_phone.offset_top = -300
	_phone.offset_bottom = 280
	add_child(_phone)
	var phone_column := VBoxContainer.new()
	phone_column.add_theme_constant_override("separation", 10)
	_phone.add_child(phone_column)
	_phone_title = Label.new()
	MangaType.ink(_phone_title, 24, MangaType.caption())
	_phone_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone_column.add_child(_phone_title)
	phone_column.add_child(HSeparator.new())
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 10)
	_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feed.alignment = BoxContainer.ALIGNMENT_END
	_feed.clip_contents = true
	phone_column.add_child(_feed)
	_phone.visible = false

	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var paper := ColorRect.new()
	paper.color = MangaType.PAPER
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(paper)
	var card_column := VBoxContainer.new()
	card_column.set_anchors_preset(Control.PRESET_CENTER)
	card_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	card_column.add_theme_constant_override("separation", 10)
	_card.add_child(card_column)
	_card_act = Label.new()
	MangaType.ink(_card_act, 34, MangaType.caption())
	_card_act.add_theme_color_override("font_color", MangaType.RED)
	_card_act.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_column.add_child(_card_act)
	_card_title = MangaType.label("", 84)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_column.add_child(_card_title)
	_card_sub = Label.new()
	MangaType.ink(_card_sub, 28, MangaType.caption())
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_column.add_child(_card_sub)
	_card.visible = false
	add_child(_card)

	_subtitle = Label.new()
	MangaType.pop(_subtitle, 32, MangaType.caption())
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle.position.y = -96
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_subtitle)

	_white = _full(Color(1, 1, 1, 0))
	_black = _full(Color(0, 0, 0, 0))
	letterbox(false)


func _bar(preset: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = MangaType.INK
	r.set_anchors_preset(preset)
	r.custom_minimum_size.y = 74
	r.offset_top = -74 if preset == Control.PRESET_BOTTOM_WIDE else 0
	r.offset_bottom = 74 if preset == Control.PRESET_TOP_WIDE else 0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _full(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func set_tokens(tokens: Dictionary) -> void:
	_tokens = tokens


func fill(text: String) -> String:
	return text.format(_tokens)


func letterbox(on: bool) -> void:
	_top.visible = on
	_bottom.visible = on


func set_caption(text: String) -> void:
	_caption.text = text
	_caption.visible = text != ""


## Lines in order, waiting for the player on each (see StoryScript for the specials).
func play(lines: Array, place := "", when := "", style := "") -> void:
	var phone := style == "phone"
	letterbox(not phone)
	set_caption("" if phone else _join(place, when))
	_phone.visible = phone
	if phone:
		_phone_title.text = _join(place, when)
		for c in _feed.get_children():
			c.queue_free()
	for line in lines:
		var who: String = line[0]
		match who:
			"~sfx":
				sfx(line[1])
				continue
			"~cut":
				await cut()
				continue
			"~place":
				if phone:
					_phone.visible = false
					phone = false
					letterbox(true)
				set_caption(line[1])
				continue
			"~wait":
				_panel.visible = false
				await get_tree().create_timer(float(line[1])).timeout
				continue
		if phone:
			await _post(who, fill(line[1]))
		else:
			await say(who, fill(line[1]))
	_panel.visible = false
	_phone.visible = false
	set_caption("")
	letterbox(false)


static func _join(place: String, when: String) -> String:
	return place + ("  ·  " + when if when != "" else "")


## One line in the speech panel ("" speaker: an ink narration box).
func say(who: String, text: String) -> void:
	var narration := who == ""
	var box := StyleBoxFlat.new()
	box.bg_color = MangaType.INK if narration else MangaType.PAPER
	box.border_color = MangaType.INK
	box.set_border_width_all(5)
	box.set_content_margin_all(22)
	box.shadow_color = MangaType.INK
	box.shadow_size = 1
	box.shadow_offset = Vector2(8, 8)
	_panel.add_theme_stylebox_override("panel", box)
	_text.add_theme_color_override("font_color", MangaType.PAPER if narration else MangaType.INK)
	_more.add_theme_color_override("font_color", MangaType.PAPER if narration else MangaType.INK)
	_name.visible = not narration
	_name.text = who
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_panel.visible = true
	_typing = true
	_more.visible = false
	await _wait_advance(text.length())


func _post(who: String, text: String) -> void:
	var bubble := PanelContainer.new()
	var box := StyleBoxFlat.new()
	var system := who == ""
	box.bg_color = MangaType.INK if who == "PANG" else Color(MangaType.PAPER, 1.0)
	box.border_color = MangaType.INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(12)
	bubble.add_theme_stylebox_override("panel", box)
	var l := Label.new()
	MangaType.ink(l, 22, MangaType.caption())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 400
	l.text = text if system else "%s\n%s" % [who, text]
	if who == "PANG":
		l.add_theme_color_override("font_color", MangaType.PAPER)
	bubble.add_child(l)
	_feed.add_child(bubble)
	while _feed.get_child_count() > 5:
		var old := _feed.get_child(0)
		_feed.remove_child(old)
		old.queue_free()
	sfx("shutter" if system else "phone_buzz", -14.0)
	_typing = false
	await _wait_advance(0)


func _wait_advance(length: int) -> void:
	_waiting = true
	if auto_advance > 0.0:
		await get_tree().create_timer(auto_advance).timeout
		_typing = false
		_text.visible_characters = -1
		_waiting = false
		advanced.emit()
		return
	await advanced
	if length > 0:
		_more.visible = false


func _process(delta: float) -> void:
	if _typing:
		_shown += delta * CHARS_PER_SECOND
		_text.visible_characters = int(_shown)
		if _shown >= _text.text.length():
			_typing = false
			_text.visible_characters = -1
	_more.visible = _waiting and not _typing and _panel.visible
	_more.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	if _subtitle_time > 0.0:
		_subtitle_time -= delta
		_subtitle.modulate.a = clampf(_subtitle_time * 2.0, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting:
		return
	var pressed: bool = event.is_action_pressed("ui_accept") or (InputMap.has_action("interact") and event.is_action_pressed("interact")) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_typing = false
		_text.visible_characters = -1
		return
	_waiting = false
	advanced.emit()


## A line over the road while driving, gone after `seconds`; does not wait.
func subtitle(who: String, text: String, seconds := 3.5) -> void:
	_subtitle.text = fill(text) if who == "" else "%s:  %s" % [who, fill(text)]
	_subtitle_time = seconds
	_subtitle.modulate.a = 1.0


## The act card: full paper page, act, title, subtitle; waits for the player.
func chapter(act: String, title: String, sub: String) -> void:
	_card_act.text = act
	_card_title.text = title
	_fit_title(title)
	_card_sub.text = sub
	_card.modulate.a = 0.0
	_card.visible = true
	await create_tween().tween_property(_card, "modulate:a", 1.0, 0.5).finished
	_waiting = true
	if auto_advance > 0.0:
		await get_tree().create_timer(auto_advance).timeout
		_waiting = false
	else:
		await advanced
	await create_tween().tween_property(_card, "modulate:a", 0.0, 0.4).finished
	_card.visible = false


## Shrink the act title until it fits the page with a margin ("WHAT HAPPENED ON THE MOUNTAIN" at
## 84 px is wider than the 1152 px canvas).
func _fit_title(title: String) -> void:
	var font := _card_title.get_theme_font("font")
	var size := 84
	while size > 40 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size / 3.0 > 1040.0:
		size -= 2
	_card_title.add_theme_font_size_override("font_size", size)
	_card_title.add_theme_constant_override("outline_size", maxi(6, size / 6))


## Fade the page to black (or back).
func fade(to_black: bool, seconds := 0.6) -> void:
	await create_tween().tween_property(_black, "color:a", 1.0 if to_black else 0.0, seconds).finished


func black(on: bool) -> void:
	_black.color.a = 1.0 if on else 0.0


## A hard cut to black and back: the join between two memories.
func cut(hold := 0.35) -> void:
	_black.color.a = 1.0
	await get_tree().create_timer(hold).timeout
	_black.color.a = 0.0


func flash_white(seconds := 0.5) -> void:
	_white.color.a = 1.0
	create_tween().tween_property(_white, "color:a", 0.0, seconds)


func sfx(name: String, db := 0.0) -> void:
	if not SFX.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = SFX[name]
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
