class_name MangaType
extends RefCounted
## Manga lettering shared by every HUD and menu: Dela Gothic One for display type (titles, menu
## items, numerals) and Bangers for captions and hints. Paper fill, ink outline and a red offset
## "extrusion" shadow, like a cover title. Both fonts are SIL OFL (assets/fonts/OFL-*.txt).

const PAPER := Color(0.953, 0.937, 0.898)
const INK := Color(0.075, 0.072, 0.07)
const RED := Color(0.886, 0.290, 0.271)

static var _display: FontFile
static var _caption: FontFile


static func display() -> Font:
	if _display == null:
		_display = load("res://assets/fonts/DelaGothicOne-Regular.ttf")
	return _display


static func caption() -> Font:
	if _caption == null:
		_caption = load("res://assets/fonts/Bangers-Regular.ttf")
	return _caption


## Paper letters with an ink outline; `extrude` adds the red offset block behind them.
static func pop(control: Control, size: int, extrude := true, font: Font = null) -> void:
	control.add_theme_font_override("font", font if font else display())
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", PAPER)
	control.add_theme_color_override("font_outline_color", INK)
	control.add_theme_constant_override("outline_size", maxi(6, size / 6))
	if extrude:
		var depth := maxi(3, size / 14)
		control.add_theme_color_override("font_shadow_color", RED)
		control.add_theme_constant_override("shadow_offset_x", depth)
		control.add_theme_constant_override("shadow_offset_y", depth)
		control.add_theme_constant_override("shadow_outline_size", maxi(6, size / 6))


## Plain ink letters on paper.
static func ink(control: Control, size: int, font: Font = null) -> void:
	control.add_theme_font_override("font", font if font else display())
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", INK)


static func label(text: String, size: int, extrude := true, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	pop(l, size, extrude, font)
	return l
