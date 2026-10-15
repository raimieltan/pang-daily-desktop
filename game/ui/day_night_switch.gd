class_name DayNightSwitch
extends CanvasLayer
## On-screen day/night switch (also N). Fades the page between day and night instead of cutting.
## Manga lettering: paper button, ink border, no color.

const PAPER := Color(0.953, 0.937, 0.898)
const INK := Color(0.075, 0.072, 0.07)
const FADE_SECONDS := 0.6

var _button := Button.new()
var _tween: Tween
var _target := -1.0


func _ready() -> void:
	layer = 5
	MangaType.ink(_button, 18)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = PAPER if state != "pressed" else INK
		box.border_color = INK
		box.set_border_width_all(4 if state == "hover" else 3)
		box.set_content_margin_all(10)
		box.content_margin_left = 16
		box.content_margin_right = 16
		_button.add_theme_stylebox_override(state, box)
	_button.add_theme_color_override("font_color", INK)
	_button.add_theme_color_override("font_hover_color", INK)
	_button.add_theme_color_override("font_pressed_color", PAPER)
	# Never take keyboard focus: Space is the handbrake and Enter restarts the run.
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_button.position = Vector2(-28, 28)
	_button.pressed.connect(toggle)
	add_child(_button)
	_refresh()


func toggle() -> void:
	var target := 0.0 if heading_to_night() else 1.0
	_target = target
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(MangaArt.apply_night, MangaArt.night, target, FADE_SECONDS * absf(target - MangaArt.night))
	_tween.tween_callback(_refresh)
	_button.text = "☾ NIGHT…" if target > 0.5 else "☀ DAY…"


## Where the page is going (mid-fade counts as already there).
func heading_to_night() -> bool:
	return _target > 0.5 if _tween and _tween.is_running() else MangaArt.night >= 0.5


func _refresh() -> void:
	_button.text = "☀ DAY  [N]" if MangaArt.night >= 0.5 else "☾ NIGHT  [N]"
