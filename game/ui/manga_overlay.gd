class_name MangaOverlay
extends CanvasLayer
## Speed lines, impact bursts and the panel border (manga_overlay.gdshader), above the 3D frame
## and below the HUD layers. Driven by the chase camera from the car's real speed.

const SHADER := preload("res://game/art/manga_overlay.gdshader")
## Speed lines fade in between these speeds (km/h).
const SPEED_LINES_FROM_KMH := 60.0
const SPEED_LINES_FULL_KMH := 160.0

var _rect := ColorRect.new()
var _material := ShaderMaterial.new()


func _ready() -> void:
	layer = 1
	_material.shader = SHADER
	_rect.material = _material
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func set_speed_kmh(kmh: float) -> void:
	_material.set_shader_parameter("speed", clampf((kmh - SPEED_LINES_FROM_KMH) / (SPEED_LINES_FULL_KMH - SPEED_LINES_FROM_KMH), 0.0, 1.0))


func set_impact(value: float) -> void:
	_material.set_shader_parameter("impact", value)
