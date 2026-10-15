class_name MangaArt
## Builds manga-style materials, restyles car models and sets up the page environment
## (docs/ART_DIRECTION.md). Every style knob lives here or in the `manga_*` shader globals
## (Project Settings → Shader Globals): tone contrast, tone density, outline scale, FX intensity, night.

const WORLD_SHADER := preload("res://game/art/manga_world.gdshader")
const CAR_SHADER := preload("res://game/art/manga_car.gdshader")
const OUTLINE_SHADER := preload("res://game/art/manga_outline.gdshader")
const POST_SHADER := preload("res://game/art/manga_post.gdshader")
const SKY_SHADER := preload("res://game/art/manga_sky.gdshader")

const PAPER := Color(0.953, 0.937, 0.898)
const INK := Color(0.075, 0.072, 0.07)

enum Pattern { DOTS, HATCH, STIPPLE }
enum Kind { PAINT, GLASS, LAMP, RUBBER, METAL }

## Grayscale hierarchy for the world. Values: lit/shadow gray (0 ink .. 1 paper), tone coverage,
## pattern, and how dark the printed tone is. Foreground objects are darker and busier; distance
## thins tone and pales value in the shader.
const WORLD_PRESETS := {
	# Road: neutral-cool mid gray, light sparse tone; shadows get directional hatching.
	"road": { "lit_value": 0.66, "shadow_value": 0.4, "darkness": 0.14, "shade": 0.3, "pattern": Pattern.DOTS,
		"shadow_pattern": Pattern.HATCH, "tone_contrast": 0.5, "pitch_scale": 1.25, "tint": Color(0.97, 0.985, 1.02),
		"road_markings": true },
	"concrete": { "lit_value": 0.9, "shadow_value": 0.52, "darkness": 0.04, "shade": 0.3, "tone_contrast": 0.6 },
	"gravel": { "lit_value": 0.74, "shadow_value": 0.44, "darkness": 0.26, "shade": 0.3, "pattern": Pattern.STIPPLE, "tone_contrast": 0.55 },
	# Cut walls: hatched rock, the darkest big surface near the road.
	"rock": { "lit_value": 0.64, "shadow_value": 0.26, "darkness": 0.34, "shade": 0.35, "pattern": Pattern.HATCH,
		"tone_contrast": 0.85, "slope_hatch": 1.0 },
	"dirt": { "lit_value": 0.76, "shadow_value": 0.44, "darkness": 0.16, "shade": 0.35, "pattern": Pattern.STIPPLE,
		"tone_contrast": 0.6, "slope_hatch": 1.0 },
	# Hillside: pale with sparse dots so trees and road read on top of it.
	"terrain": { "lit_value": 0.88, "shadow_value": 0.56, "darkness": 0.12, "shade": 0.35, "tone_contrast": 0.55,
		"slope_hatch": 0.6, "far_value": 0.9 },
	# Guardrail: the brightest line on the valley side; posts are ink.
	"guardrail": { "lit_value": 0.98, "shadow_value": 0.72, "darkness": 0.0, "shade": 0.2, "tone_contrast": 0.5 },
	"post": { "lit_value": 0.16, "shadow_value": 0.08, "darkness": 0.0, "shade": 0.0 },
	# Cedars: dark hatched masses near, mid-gray in the midground, pale far away.
	"leaves": { "lit_value": 0.4, "shadow_value": 0.16, "darkness": 0.42, "shade": 0.3, "pattern": Pattern.HATCH,
		"tone_contrast": 0.9, "near_detail": 20.0, "far_detail": 200.0, "far_value": 0.74 },
	"trunk": { "lit_value": 0.14, "shadow_value": 0.06, "darkness": 0.0, "shade": 0.0, "far_value": 0.6 },
	# Distant mountain ring: light gray silhouettes with almost no tone.
	"backdrop": { "lit_value": 0.8, "shadow_value": 0.68, "darkness": 0.08, "shade": 0.2, "tone_contrast": 0.35,
		"near_detail": 600.0, "far_detail": 1800.0, "far_value": 0.84 },
}

## Night state mirrored from the `manga_night` shader global (reading globals back is slow).
static var night := 0.0
static var _fx := 1.0


static func fx_intensity() -> float:
	return _fx


static func set_fx_intensity(value: float) -> void:
	_fx = value
	RenderingServer.global_shader_parameter_set("manga_fx_intensity", value)


static func world_preset(name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	var p: Dictionary = WORLD_PRESETS[name]
	for key in p:
		var v = p[key]
		m.set_shader_parameter(key, float(v) if v is int else v)
	return m


static func road() -> ShaderMaterial:
	return world_preset("road")


## Flat colored accent (gantry banners, signs): cel color without a glint.
static func accent(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CAR_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("glint", false)
	m.set_shader_parameter("highlight", 0.15)
	return m


static func outline(width := 0.02) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("ink", INK)
	return m


## Restyles a car model in place. Returns the materials by GLB material name, so the visual can
## drive lamp glow from the car's state. Outline width is per part: heavy on the body silhouette,
## thin on small details, so contours stay selective.
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
	var width := 0.01
	var glint := false
	match name:
		"paint":
			color = paint; glint = true; width = 0.022
		"glass":
			kind = Kind.GLASS; width = 0.012
		"tire":
			kind = Kind.RUBBER; width = 0.018
		"trim", "engine_dark":
			kind = Kind.RUBBER; width = 0.012
		"rim", "chrome":
			kind = Kind.METAL; color = Color(0.82, 0.82, 0.8); width = 0.008
		"rim_dark", "engine_metal":
			kind = Kind.METAL; color = Color(0.42, 0.42, 0.43); width = 0.008
		"plate":
			color = PAPER; width = 0.006
		"taillight":
			kind = Kind.LAMP; color = Color(0.92, 0.06, 0.08); width = 0.008
		"headlight":
			kind = Kind.LAMP; color = Color(1.0, 0.93, 0.72); width = 0.008
		"amber":
			kind = Kind.LAMP; color = Color(1.0, 0.58, 0.12); width = 0.006
		"reverse":
			kind = Kind.LAMP; color = Color(0.95, 0.95, 0.92); width = 0.006
	m.set_shader_parameter("kind", int(kind))
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("glint", glint)
	m.next_pass = outline(width)
	return m


## Full-screen page pass, parented to a camera. Set "speed_lines" / "impact" on its material.
static func post_quad() -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	quad.name = "MangaPage"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	quad.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = POST_SHADER
	quad.material_override = m
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = Vector3(0, 0, -1)
	return quad


## Manga sky as the background; no ambient or reflections (the shaders do their own lighting).
static func environment() -> Environment:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	# Nothing samples radiance, so keep it tiny and never update it in real time.
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false
	return env


static func sun(energy := 1.0) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-38, 140, 0)
	light.light_energy = energy
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 120.0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	return light


## Day/night: the page goes dark and car lamps become the light (docs/ART_DIRECTION.md §3, §6).
static func set_night(on: bool) -> void:
	night = 1.0 if on else 0.0
	RenderingServer.global_shader_parameter_set("manga_night", night)
