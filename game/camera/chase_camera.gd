class_name ChaseCamera
extends Camera3D
## Third-person chase camera. Swings behind the direction of travel (not the nose), so slides
## stay readable, and lags a little so speed and weight transfer show.

@export var distance := 5.6
@export var height := 1.9
@export var look_height := 0.9
@export var follow_rate := 6.0
@export var swing_rate := 3.0

var target: CarBody
var _yaw := 0.0
var _page: MeshInstance3D


func _ready() -> void:
	# Moved in _process from the interpolated car transform, so it must not interpolate itself.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = 68.0
	near = 0.1
	far = 3000.0
	_page = MangaArt.post_quad()
	add_child(_page)


func snap() -> void:
	if target:
		_yaw = _heading(-target.global_basis.z)
		global_position = _desired(target.global_position)


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
	(_page.material_override as ShaderMaterial).set_shader_parameter("speed_lines", smoothstep(16.0, 36.0, speed))
	fov = lerpf(fov, 68.0 + clampf(speed * 0.25, 0.0, 12.0), 1.0 - exp(-2.0 * delta))
	look_at(xf.origin + Vector3.UP * look_height)


func _desired(origin: Vector3) -> Vector3:
	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	return origin + back * distance + Vector3.UP * height


## Yaw that points the camera's back vector opposite to `direction`.
static func _heading(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
