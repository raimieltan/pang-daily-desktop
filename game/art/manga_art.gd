class_name MangaArt
## Manga look (docs/ART_DIRECTION.md). Scene materials output grayscale (world) or toon color (the
## car); the MangaCompositor turns grayscale into ink / screentone / paper and adds ink lines;
## MangaOverlay draws speed lines, impact bursts and the panel border on a CanvasLayer.
## Global knobs live in the `manga_*` shader globals (Project Settings → Shader Globals).

const WORLD_SHADER := preload("res://game/art/manga_world.gdshader")
const CAR_SHADER := preload("res://game/art/manga_car.gdshader")
const OUTLINE_SHADER := preload("res://game/art/manga_outline.gdshader")
const SKY_SHADER := preload("res://game/art/manga_sky.gdshader")

const PAPER := Color("#F3EDE1")
const INK := Color("#111111")
## Spot colors allowed in the world (sparingly): sodium street lamps and red sign lettering.
const SODIUM := Color(1.0, 0.6, 0.2)
const SIGN_RED := Color(0.8, 0.07, 0.05)

enum Kind { PAINT, GLASS, LAMP, RUBBER, METAL }

## Albedo grays for the world (0 ink .. 1 paper) and how they shade. The compositor bands the lit
## result: at night most of the world falls into ink and dense tone, and headlights cut paper out of it.
const WORLD_PRESETS := {
	"road": { "lit_value": 0.55, "road_markings": true },
	"concrete": { "lit_value": 0.85 },
	"gravel": { "lit_value": 0.6 },
	"rock": { "lit_value": 0.5, "slope_darken": 0.35 },
	"dirt": { "lit_value": 0.6, "slope_darken": 0.25 },
	"terrain": { "lit_value": 0.75, "slope_darken": 0.3, "far_value": 0.88 },
	"guardrail": { "lit_value": 0.95 },
	"post": { "lit_value": 0.12 },
	"leaves": { "lit_value": 0.36, "near_detail": 25.0, "far_detail": 300.0, "far_value": 0.7 },
	"bush": { "lit_value": 0.42 },
	"grass": { "lit_value": 0.5 },
	"trunk": { "lit_value": 0.12 },
	"backdrop": { "lit_value": 0.7, "flat_light": true, "near_detail": 600.0, "far_detail": 1800.0, "far_value": 0.8 },
	"sign": { "lit_value": 0.95, "pattern_mode": 1 },
	"delineator": { "lit_value": 0.95, "pattern_mode": 2 },
	"pole": { "lit_value": 0.3 },
	"lamp_head": { "lit_value": 0.9 },
	"board": { "lit_value": 0.95 },
}

## Day/night state (0 day .. 1 night), mirrored from the `manga_night` global.
static var night := 1.0
static var _fx := 1.0
static var _sun: DirectionalLight3D


static func world_preset(name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	var p: Dictionary = WORLD_PRESETS[name]
	for key in p:
		var v = p[key]
		m.set_shader_parameter(key, v)
	return m


static func road() -> ShaderMaterial:
	return world_preset("road")


## Flat colored accent (gantry banners): toon color, no glint.
static func accent(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CAR_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("glint", false)
	m.set_shader_parameter("streak_width", 0.0)
	return m


## A lit lamp face in the world (street lamp heads): toon color plus a steady glow.
static func lamp(color: Color, glow := 0.8) -> ShaderMaterial:
	var m := accent(color)
	m.set_shader_parameter("kind", int(Kind.LAMP))
	m.set_shader_parameter("glow", glow)
	return m


static func outline(width := 0.014) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("ink", INK)
	return m


static func fx_intensity() -> float:
	return _fx


static func set_fx_intensity(value: float) -> void:
	_fx = value
	RenderingServer.global_shader_parameter_set("manga_fx_intensity", value)


## Restyles a car model in place; returns materials by GLB material name (lamps are driven later).
static func apply_car(model: Node, paint: Color) -> Dictionary:
	var cache := {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var source := mi.get_active_material(i)
			var key := source.resource_name if source else ""
			if not cache.has(key):
				cache[key] = _car_material(key, source, paint)
			mi.set_surface_override_material(i, cache[key])
	return cache


static func _car_material(name: String, source: Material, paint: Color) -> ShaderMaterial:
	var base := (source as BaseMaterial3D).albedo_color if source is BaseMaterial3D else Color.GRAY
	var m := ShaderMaterial.new()
	m.shader = CAR_SHADER
	var kind := Kind.PAINT
	var color := base
	var width := 0.008
	var glint := false
	match name:
		"paint":
			color = paint; glint = true; width = 0.016
		"glass":
			kind = Kind.GLASS; width = 0.008
		"tire":
			kind = Kind.RUBBER; width = 0.012
		"trim", "engine_dark":
			kind = Kind.RUBBER
		"rim", "chrome", "rim_dark", "engine_metal":
			kind = Kind.METAL; width = 0.006
		"plate":
			color = PAPER
		"taillight":
			kind = Kind.LAMP; color = Color(0.92, 0.06, 0.08)
		"headlight":
			kind = Kind.LAMP; color = PAPER
		"amber":
			kind = Kind.LAMP; color = Color(1.0, 0.58, 0.12)
		"reverse":
			kind = Kind.LAMP; color = PAPER
	m.set_shader_parameter("kind", int(kind))
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("glint", glint)
	if kind != Kind.PAINT:
		m.set_shader_parameter("streak_width", 0.0)
	m.next_pass = outline(width)
	return m


## Sky is the manga sky shader: black with point stars at night, paper with inked clouds by day.
static func environment() -> Environment:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	# Nothing samples radiance; keep it tiny and never update it in real time.
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false
	return env


## The one directional light: the sun by day, a dim moon by night (see `apply_night`).
static func sun() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	# Low afternoon sun: long raking shadows across the road.
	light.rotation_degrees = Vector3(-24, 125, 0)
	light.shadow_enabled = true
	# Hard shadows (manga) over a short distance: far away everything is tone and silhouette.
	light.directional_shadow_max_distance = 80.0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun = light
	apply_night(night)
	return light


static func set_night(on: bool) -> void:
	apply_night(1.0 if on else 0.0)


## 0 = day .. 1 = night. Blends the sky, the light (sun → moon) and the ambient term.
static func apply_night(value: float) -> void:
	night = value
	RenderingServer.global_shader_parameter_set("manga_night", value)
	# Night ambient keeps unlit faces in tone rather than flat ink; ink is for real shadows.
	RenderingServer.global_shader_parameter_set("manga_ambient", lerpf(0.3, 0.07, value))
	if is_instance_valid(_sun):
		# Moonlight is just enough to separate lit slopes (dense tone) from shadow (ink).
		# Day sun kept moderate: lit surfaces sit in the gray bands so their detail survives.
		_sun.light_energy = lerpf(0.62, 0.18, value)
