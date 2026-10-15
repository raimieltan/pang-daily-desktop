class_name ChaseCamera
extends Camera3D
## Third-person chase camera. Swings behind the direction of travel (not the nose), so slides
## stay readable, and lags a little so speed and weight transfer show. Looks a little ahead with
## speed so the upcoming corner stays in frame and the car sits in the lower third. Owns the manga
## page pass (speed lines, impact frames) and impact shake.

@export var distance := 5.6
@export var height := 1.9
@export var look_height := 0.9
@export var follow_rate := 6.0
@export var swing_rate := 3.0
## Metres the aim point moves ahead per m/s, capped.
@export var look_ahead := 0.14
@export var max_look_ahead := 4.5

var target: CarBody
var _yaw := 0.0
var _page: MeshInstance3D
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
	_page = MangaArt.post_quad()
	add_child(_page)
	_noise.frequency = 2.5
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func _on_resize() -> void:
	RenderingServer.global_shader_parameter_set("manga_res_scale", get_viewport().get_visible_rect().size.y / 1080.0)


func snap() -> void:
	if target:
		_yaw = _heading(-target.global_basis.z)
		global_position = _desired(target.global_position)


## A hard hit: a short impact frame on the page and some camera shake. 0..1.
func add_impact(severity: float) -> void:
	_impact = maxf(_impact, severity)
	_trauma = minf(1.0, _trauma + severity * 0.7)


func _process(delta: float) -> void:
	if target == null:
		return
	var xf := target.get_global_transform_interpolated()
	var forward := -xf.basis.z
	var velocity := target.linear_velocity
	velocity.y = 0.0
	# Follow the travel direction once moving forward; the nose when crawling or reversing.
	var direction := velocity.normalized() if velocity.dot(forward) > 3.0 else forward
	var wanted := _heading(direction)
	_yaw = lerp_angle(_yaw, wanted, 1.0 - exp(-swing_rate * delta))
	global_position = global_position.lerp(_desired(xf.origin), 1.0 - exp(-follow_rate * delta))
	var speed := velocity.length()
	fov = lerpf(fov, 68.0 + clampf(speed * 0.25, 0.0, 12.0), 1.0 - exp(-2.0 * delta))
	var ahead := direction * minf(speed * look_ahead, max_look_ahead)
	look_at(xf.origin + Vector3.UP * look_height + ahead)
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
	var page := _page.material_override as ShaderMaterial
	page.set_shader_parameter("speed_lines", smoothstep(17.0, 34.0, speed))
	page.set_shader_parameter("impact", _impact)


func _desired(origin: Vector3) -> Vector3:
	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	return origin + back * distance + Vector3.UP * height


## Yaw that points the camera's back vector opposite to `direction`.
static func _heading(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
