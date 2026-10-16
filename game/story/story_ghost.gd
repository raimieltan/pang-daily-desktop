class_name StoryGhost
extends Node3D
## The Ghost Line on the road outside a timed run: the car as a see-through pencil sketch (the PB
## ghost's shader), shown at a pose or hidden, with its own opacity.

const GHOST_SHADER := preload("res://game/art/manga_ghost.gdshader")

var model_path := ""
var opacity := 0.35:
	set(v):
		opacity = v
		if _material:
			_material.set_shader_parameter("opacity", v)
var _material: ShaderMaterial


func _ready() -> void:
	var model: Node3D = (load(model_path) as PackedScene).instantiate()
	model.rotation.y = PI
	add_child(model)
	_material = ShaderMaterial.new()
	_material.shader = GHOST_SHADER
	_material.set_shader_parameter("opacity", opacity)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.material_override = _material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = CarVisual.CAR_RENDER_LAYER
	visible = false


func show_pose(pose: Dictionary) -> void:
	visible = not pose.is_empty()
	if visible:
		global_transform = Transform3D(Basis(pose["rotation"]), pose["position"])
