class_name MangaArt
## Builds manga-style materials, restyles car models and sets up the page environment
## (docs/ART_DIRECTION.md). Keep every style knob here so the look is tuned in one place.

const WORLD_SHADER := preload("res://game/art/manga_world.gdshader")
const CAR_SHADER := preload("res://game/art/manga_car.gdshader")
const OUTLINE_SHADER := preload("res://game/art/manga_outline.gdshader")
const POST_SHADER := preload("res://game/art/manga_post.gdshader")

const PAPER := Color(0.949, 0.937, 0.902)
const INK := Color(0.078, 0.078, 0.078)

enum Pattern { DOTS, HATCH, STIPPLE }


static func world(darkness: float, pattern := Pattern.DOTS, shade := 0.45, slope_hatch := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("darkness", darkness)
	m.set_shader_parameter("pattern", float(pattern))
	m.set_shader_parameter("shade", shade)
	m.set_shader_parameter("slope_hatch", slope_hatch)
	return m


static func road() -> ShaderMaterial:
	var m := world(0.32, Pattern.DOTS, 0.5)
	m.set_shader_parameter("road_markings", true)
	return m


## Flat colored accent (gantry banners, signs): cel color without a glint.
static func accent(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CAR_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("glint", false)
	m.set_shader_parameter("hatch_amount", 0.25)
	return m


static func outline(width := 0.025) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("ink", INK)
	return m


## Restyles a car model in place: paint gets `paint`, glass and tires go ink, lamps keep their
## color, chrome and rims go paper or tone. Every mesh gets an ink outline shell.
static func apply_car(model: Node, paint: Color) -> void:
	var cache := {}
	var shell := outline(0.022)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var source := mi.get_active_material(i)
			var key := source.resource_name if source else ""
			if not cache.has(key):
				cache[key] = _car_material(key, source, paint, shell)
			mi.set_surface_override_material(i, cache[key])


static func _car_material(name: String, source: Material, paint: Color, shell: Material) -> Material:
	var base := (source as BaseMaterial3D).albedo_color if source is BaseMaterial3D else Color.GRAY
	var m := ShaderMaterial.new()
	m.shader = CAR_SHADER
	var color := base
	var glint := false
	var hatch := 0.35
	var lamp := false
	match name:
		"paint":
			color = paint
			glint = true
		"glass":
			color = Color(0.09, 0.1, 0.12)
			glint = true
			hatch = 0.0
		"tire", "trim", "engine_dark":
			color = Color(0.1, 0.1, 0.1)
			hatch = 0.0
		"rim", "chrome", "plate", "reverse", "headlight":
			color = PAPER if name != "rim" else Color(0.78, 0.78, 0.76)
			glint = name == "chrome"
		"rim_dark":
			color = Color(0.32, 0.32, 0.33)
		"taillight", "amber":
			color = base.lightened(0.15)
			lamp = true
		_:
			color = base
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("glint", glint)
	m.set_shader_parameter("hatch_amount", hatch)
	m.set_shader_parameter("lamp", lamp)
	m.next_pass = shell
	return m


## Full-screen page pass, parented to a camera. Returns the quad; set "speed_lines" on its material.
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


## Paper sky, no color grading, no fog (the page pass fades distance to paper).
static func environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = PAPER
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false
	return env


static func sun(energy := 1.0) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, 140, 0)
	light.light_energy = energy
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 120.0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	return light
