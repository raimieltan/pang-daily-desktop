class_name StoryTint
extends CanvasLayer
## The memories' warmth: one multiply-blend wash over the whole page (the 3D pass and every UI
## panel alike), so paper goes cream and ink stays ink. Off in the present.

const WARM := Color(1.0, 0.94, 0.82)

var _wash: ColorRect


func _ready() -> void:
	layer = 20
	_wash = ColorRect.new()
	_wash.color = WARM
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_wash.material = m
	_wash.visible = false
	add_child(_wash)


func set_warm(on: bool) -> void:
	_wash.visible = on
