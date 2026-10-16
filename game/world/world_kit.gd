class_name WorldKit
## Buildings modelled in Blender (tools/world_builders/), restyled for the manga page.
## Material names carry the intent (see tools/world_builders/kit.py):
##   a `MangaArt.WORLD_PRESETS` name → that preset; "accent_*" → a flat spot colour;
##   "lamp_*" → a glowing colour; anything else → world tone, lit value from the colour's brightness.
## Each GLB's origin sits at a known hub point (`place`), so the layout units carry over.


## Instances the GLB at `path`, restyles it and puts its origin at hub point (x, z).
static func place(parent: Node3D, path: String, x: float, z: float) -> Node3D:
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.position = HubLayout.pos(x, z)
	parent.add_child(model)
	restyle(model)
	return model


static func restyle(model: Node) -> void:
	var cache := {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var source := mi.get_active_material(i)
			var key := source.resource_name if source else ""
			if not cache.has(key):
				var color := (source as BaseMaterial3D).albedo_color if source is BaseMaterial3D else Color.GRAY
				cache[key] = material(key, color)
			mi.set_surface_override_material(i, cache[key])
	# "-colonly" colliders import as StaticBody3D on layer 1, which is CarBody.STATIC_LAYER.
	for node in model.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		body.collision_layer = CarBody.STATIC_LAYER
		body.collision_mask = 0


static func material(name: String, color: Color) -> Material:
	if name.begins_with("accent_"):
		return MangaArt.accent(color)
	if name.begins_with("lamp_"):
		return MangaArt.lamp(color, 0.8)
	if MangaArt.WORLD_PRESETS.has(name):
		return MangaArt.world_preset(name)
	return tone(color.get_luminance())


## World tone at a lit value (0 ink .. 1 paper), for anything with no preset of its own.
static func tone(lit: float) -> ShaderMaterial:
	var m := MangaArt.world_preset("concrete")
	m.set_shader_parameter("lit_value", clampf(lit, 0.08, 0.96))
	return m
