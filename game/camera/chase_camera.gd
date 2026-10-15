class_name ChaseCamera
extends Camera3D
## Third-person chase camera. Swings behind the direction of travel (not the nose), so slides
## stay readable, lags a little so speed and weight transfer show, and looks a little ahead with
## speed. Owns the manga page: the MangaCompositor pass (tone + ink lines), the MangaOverlay
## (speed lines, impact, panel border) and impact shake. M toggles the manga pass for comparison.
## V cycles the view: chase, far chase, hood and bumper (mounted on the car body).

signal mode_changed(mode: Mode)

enum Mode { CHASE, FAR, HOOD, BUMPER }
const MODE_NAMES := ["CHASE", "FAR", "HOOD", "BUMPER"]
## Chase rigs: [distance, height, look_height]. Mounted views: car-local eye point.
const CHASE_RIGS := { Mode.CHASE: [5.6, 1.9, 0.9], Mode.FAR: [8.6, 3.0, 1.0] }
const MOUNTS := { Mode.HOOD: Vector3(0.0, 1.22, -0.45), Mode.BUMPER: Vector3(0.0, 0.52, -2.25) }

@export var distance := 5.6
@export var height := 1.9
@export var look_height := 0.9
@export var follow_rate := 6.0
@export var swing_rate := 3.0
## Metres the aim point moves ahead per m/s, capped.
@export var look_ahead := 0.14
@export var max_look_ahead := 4.5

var target: CarBody
var mode := Mode.CHASE:
	set(value):
		mode = value
		if CHASE_RIGS.has(mode):
			distance = CHASE_RIGS[mode][0]
			height = CHASE_RIGS[mode][1]
			look_height = CHASE_RIGS[mode][2]
		# Hide the car's own body in the bumper view: the eye sits just ahead of the nose.
		cull_mask = 0xFFFFF & ~CarVisual.CAR_RENDER_LAYER if mode == Mode.BUMPER else 0xFFFFF
		snap()
		mode_changed.emit(mode)
var manga: MangaCompositor
var overlay: MangaOverlay
var _yaw := 0.0
var _trauma := 0.0
var _impact := 0.0
var _shake_t := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	# Moved in _process from the interpolated car transform, so it must not interpolate itself.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = 68.0
	near = 0.1
	far = 3000.0
	manga = MangaCompositor.new()
	var comp := Compositor.new()
	comp.compositor_effects = [manga]
	compositor = comp
	overlay = MangaOverlay.new()
	add_child(overlay)
	_noise.frequency = 2.5
	get_viewport().size_changed.connect(_fit_render_scale)
	_fit_render_scale()
	if not InputMap.has_action("toggle_manga"):
		InputMap.add_action("toggle_manga")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_M
		InputMap.action_add_event("toggle_manga", e)
	if not InputMap.has_action("cycle_camera"):
		InputMap.add_action("cycle_camera")
		var v := InputEventKey.new()
		v.physical_keycode = KEY_V
		InputMap.action_add_event("cycle_camera", v)
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_Y
		InputMap.action_add_event("cycle_camera", pad)


## Above `MAX_3D_HEIGHT` pixels the 3D (and the manga pass) renders at a lower internal scale and
## FSR1 upscales it; the HUD and overlay stay native. Measured 3340×1878 on an M1: 18.3 ms at 0.77, 14.6 ms (68 fps) at 0.64.
const MAX_3D_HEIGHT := 1200.0


func _fit_render_scale() -> void:
	var vp := get_viewport()
	# Real pixels: with canvas_items stretch the visible rect is the base canvas size instead.
	var h := float(get_window().size.y)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = clampf(MAX_3D_HEIGHT / maxf(h, 1.0), 0.6, 1.0)
	vp.fsr_sharpness = 0.4


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_manga"):
		manga.enabled = not manga.enabled
		overlay.visible = manga.enabled
	elif event.is_action_pressed("cycle_camera"):
		mode = ((mode + 1) % Mode.size()) as Mode


func snap() -> void:
	if target == null or not is_inside_tree():
		return
	_yaw = _heading(-target.global_basis.z)
	if MOUNTS.has(mode):
		_mount(target.global_transform, 0.0)
	else:
		global_position = _desired(target.global_position)


## A hard hit: a short impact burst on the page and some camera shake. 0..1.
func add_impact(severity: float) -> void:
	_impact = maxf(_impact, severity)
	_trauma = minf(1.0, _trauma + severity * 0.7)


func _process(delta: float) -> void:
	# Sky stars are sized in pixels: tell it how many radians one pixel spans.
	var h := float(get_window().size.y)
	RenderingServer.global_shader_parameter_set("manga_px_angle", deg_to_rad(fov) / maxf(h, 1.0))
	if target == null:
		return
	var xf := target.get_global_transform_interpolated()
	var forward := -xf.basis.z
	var velocity := target.linear_velocity
	velocity.y = 0.0
	# Follow the travel direction once moving forward; the nose when crawling or reversing.
	var direction := velocity.normalized() if velocity.dot(forward) > 3.0 else forward
	_yaw = lerp_angle(_yaw, _heading(direction), 1.0 - exp(-swing_rate * delta))
	global_position = global_position.lerp(_desired(xf.origin), 1.0 - exp(-follow_rate * delta))
	var speed := velocity.length()
	if MOUNTS.has(mode):
		# Mounted views ride the body; wider FOV so speed reads from the road rushing past.
		fov = lerpf(fov, 76.0 + clampf(speed * 0.2, 0.0, 10.0), 1.0 - exp(-2.0 * delta))
		_mount(xf, speed)
	else:
		fov = lerpf(fov, 68.0 + clampf(speed * 0.25, 0.0, 12.0), 1.0 - exp(-2.0 * delta))
		look_at(xf.origin + Vector3.UP * look_height + direction * minf(speed * look_ahead, max_look_ahead))
	# Shake: trauma² so small knocks barely move the frame.
	_trauma = maxf(0.0, _trauma - delta * 1.6)
	if _trauma > 0.0:
		_shake_t += delta * 30.0
		var s := _trauma * _trauma
		rotate_object_local(Vector3.RIGHT, _noise.get_noise_1d(_shake_t) * 0.05 * s)
		rotate_object_local(Vector3.UP, _noise.get_noise_1d(_shake_t + 100.0) * 0.05 * s)
		h_offset = _noise.get_noise_1d(_shake_t + 200.0) * 0.25 * s
	else:
		h_offset = 0.0
	_impact = maxf(0.0, _impact - delta * 3.5)
	overlay.set_speed_kmh(speed * 3.6)
	overlay.set_impact(_impact * MangaArt.fx_intensity())


## Eye fixed to the car body, levelled a little so body roll reads without the horizon swimming.
func _mount(xf: Transform3D, _speed: float) -> void:
	var eye: Vector3 = xf * MOUNTS[mode]
	var forward := -xf.basis.z
	var up := xf.basis.y.lerp(Vector3.UP, 0.6).normalized()
	global_transform = Transform3D(Basis.looking_at(forward, up), eye)


func _desired(origin: Vector3) -> Vector3:
	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	return origin + back * distance + Vector3.UP * height


## Yaw that points the camera's back vector opposite to `direction`.
static func _heading(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
