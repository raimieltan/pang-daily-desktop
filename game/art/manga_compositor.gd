@tool
class_name MangaCompositor
extends CompositorEffect
## The manga page pass (compute, after the transparent pass): tone ramp into 4 bands with
## screen-space screentone, Sobel ink lines on depth + normals, paper grain and ink bleed.
## Saturated pixels (the player car and its lights) keep their color. See manga_post.glsl.
## Toggle with `enabled` (the M debug key does this for comparison).

@export_group("Tone ramp")
## Luminance (perceptual, 0..1) splits between ink | dense tone | sparse tone | paper.
@export_range(0.0, 1.0) var ink_below := 0.2
@export_range(0.0, 1.0) var dense_below := 0.4
@export_range(0.0, 1.0) var sparse_below := 0.64
## Screentone pitch at 1080p in pixels (scaled with resolution).
@export_range(2.0, 16.0) var tone_pitch := 5.0
@export_range(0.0, 1.0) var dense_coverage := 0.55
@export_range(0.0, 1.0) var sparse_coverage := 0.16
## Dense band: crosshatch (true) or heavy dots (false).
@export var dense_crosshatch := true

@export_group("Ink lines")
## Silhouette (depth) and crease (normal) kernel offsets at 1080p, in pixels.
@export_range(0.5, 4.0) var silhouette_px := 1.6
@export_range(0.5, 3.0) var crease_px := 1.0
## Lines thin out toward this distance (m); creases stop at `crease_far`.
@export var line_far := 160.0
@export var crease_far := 45.0
@export_range(0.001, 0.5) var depth_sensitivity := 0.05
@export_range(0.01, 1.0) var normal_sensitivity := 0.3
## Hand-inked wobble: offset in pixels, noise feature size in pixels.
@export_range(0.0, 3.0) var jitter_px := 0.7
@export_range(4.0, 200.0) var jitter_scale := 40.0
## Silhouettes over solid-ink background turn white so they still read at night.
@export var white_lines_on_ink := true

@export_group("Paper")
@export var paper_color := Color("#F3EDE1")
@export var ink_color := Color("#111111")
@export_range(0.0, 0.3) var grain := 0.06
@export_range(0.0, 1.0) var ink_bleed := 0.25

@export_group("Color exception")
## Pixels more saturated than this skip the ramp (the car's paint and lights).
@export_range(0.0, 1.0) var car_saturation := 0.24

const PARAMS_BYTES := 144

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _params: RID
var _sampler: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	needs_normal_roughness = true
	RenderingServer.call_on_render_thread(_initialize)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		for rid in [_pipeline, _shader, _params, _sampler]:
			if rid.is_valid():
				_rd.free_rid(rid)


func _initialize() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	var file: RDShaderFile = load("res://game/art/manga_post.glsl")
	var spirv := file.get_spirv()
	if spirv.compile_error_compute != "":
		push_error("manga_post.glsl: " + spirv.compile_error_compute)
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	_pipeline = _rd.compute_pipeline_create(_shader)
	# std140: 9 × vec4.
	_params = _rd.uniform_buffer_create(PARAMS_BYTES)
	var s := RDSamplerState.new()
	s.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	s.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	s.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	s.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = _rd.sampler_create(s)


## Linear depth from the inverse projection: for a perspective camera, view z and w depend only on
## depth d, so z = -(a·d + b) / (c·d + e). Saves a mat4 multiply per depth tap on the GPU.
func _depth_coef(inv_proj: Projection) -> PackedFloat32Array:
	return PackedFloat32Array([inv_proj.z.z, inv_proj.w.z, inv_proj.z.w, inv_proj.w.w])


func _render_callback(_type: int, render_data: RenderData) -> void:
	if not _pipeline.is_valid():
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene := render_data.get_render_scene_data()
	if buffers == null or scene == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	var paper := paper_color.srgb_to_linear()
	var ink := ink_color.srgb_to_linear()
	var groups := Vector2i(ceili(size.x / 8.0), ceili(size.y / 8.0))
	for view in buffers.get_view_count():
		var f := _depth_coef(scene.get_view_projection(view).inverse())
		f.append_array([
			size.x, size.y, 1.0 / size.x, 1.0 / size.y,
			ink_below, dense_below, sparse_below, tone_pitch,
			dense_coverage, sparse_coverage, 1.0 if dense_crosshatch else 0.0, 0.0,
			silhouette_px, crease_px, line_far, crease_far,
			depth_sensitivity, normal_sensitivity, jitter_px, jitter_scale,
			paper.r, paper.g, paper.b, grain,
			ink.r, ink.g, ink.b, ink_bleed,
			car_saturation, 1.0 if white_lines_on_ink else 0.0, 1.0, 0.0,
		])
		var bytes := f.to_byte_array()
		_rd.buffer_update(_params, 0, bytes.size(), bytes)

		var color := buffers.get_color_layer(view)
		var depth := buffers.get_depth_layer(view)
		var normal := buffers.get_texture("forward_clustered", "normal_roughness")
		var u_color := RDUniform.new()
		u_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_color.binding = 0
		u_color.add_id(color)
		var u_depth := RDUniform.new()
		u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u_depth.binding = 1
		u_depth.add_id(_sampler)
		u_depth.add_id(depth)
		var u_normal := RDUniform.new()
		u_normal.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u_normal.binding = 2
		u_normal.add_id(_sampler)
		u_normal.add_id(normal)
		var u_params := RDUniform.new()
		u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
		u_params.binding = 3
		u_params.add_id(_params)
		var uniform_set := UniformSetCacheRD.get_cache(_shader, 0, [u_color, u_depth, u_normal, u_params])

		var list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _pipeline)
		_rd.compute_list_bind_uniform_set(list, uniform_set, 0)
		_rd.compute_list_dispatch(list, groups.x, groups.y, 1)
		_rd.compute_list_end()
