class_name CarFx
extends Node3D
## World-space driving effects, all driven by the sim (docs/ART_DIRECTION.md §4):
## ink skid marks and manga cloud smoke from per-wheel slip, yellow-orange sparks from wall
## scrapes, and impact frames + camera trauma from hard hits. Lives outside the car so marks and
## particles stay in the world.

const SMOKE_SHADER := preload("res://game/art/manga_smoke.gdshader")
const MAX_SEGMENTS := 2400
const SKID_WIDTH := 0.19
const SKID_STEP := 0.35
## Slip that starts marking: slip angle (rad) or slip ratio.
const SLIDE_ANGLE := 0.14
const SLIDE_RATIO := 0.22

var car: CarBody
var camera: ChaseCamera

var _skid_mesh := ImmediateMesh.new()
var _skid_instance := MeshInstance3D.new()
# Ring buffer of quads: 4 corners + intensity each.
var _segments: Array[PackedVector3Array] = []
var _alphas := PackedFloat32Array()
var _next := 0
var _dirty := false
var _last_point: Array = [null, null, null, null]
var _smoke: Array[CPUParticles3D] = []
var _sparks: CPUParticles3D
var _burst: CPUParticles3D
var _scrape_timer := 0.0


func _ready() -> void:
	top_level = true
	_skid_instance.mesh = _skid_mesh
	_skid_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var skid_mat := StandardMaterial3D.new()
	skid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skid_mat.vertex_color_use_as_albedo = true
	skid_mat.render_priority = -1
	_skid_instance.material_override = skid_mat
	add_child(_skid_instance)
	for i in 4:
		_smoke.append(_make_smoke())
	_sparks = _make_sparks(90, 0.1)
	_burst = _make_sparks(48, 0.95)
	_burst.one_shot = true
	if car:
		car.wall_contact.connect(_on_wall_contact)


func _physics_process(delta: float) -> void:
	if car == null or car.model == null:
		return
	var mech := car.model.mechanics
	var speed := car.linear_velocity.length()
	var right := car.global_basis.x
	for i in 4:
		var w := mech.wheels[i]
		var c := car.wheel_contact(i)
		var sliding: bool = c["grounded"] and speed > 3.0 and (absf(w.slip_angle) > SLIDE_ANGLE or absf(w.slip_ratio) > SLIDE_RATIO or w.is_locked)
		var amount := clampf(w.slip_energy / 22000.0, 0.25, 1.0) if sliding else 0.0
		var point: Vector3 = c["point"] + (c["normal"] as Vector3) * 0.02
		if sliding:
			var last = _last_point[i]
			if last == null:
				_last_point[i] = point
			elif point.distance_to(last) > SKID_STEP:
				_add_segment(last, point, right, amount)
				_last_point[i] = point
		else:
			_last_point[i] = null
		var smoke := _smoke[i]
		smoke.global_position = point + Vector3.UP * 0.15
		# Only heavy slides smoke, and only the rears unless the fronts are spinning.
		smoke.emitting = sliding and amount > 0.6 and speed > 6.0 and (i >= 2 or w.is_spinning)
	_scrape_timer = maxf(0.0, _scrape_timer - delta)
	_sparks.emitting = _scrape_timer > 0.0


func _process(_delta: float) -> void:
	if _dirty:
		_rebuild_skids()


func _add_segment(a: Vector3, b: Vector3, right: Vector3, amount: float) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP).normalized() * SKID_WIDTH * 0.5
	if side.length_squared() < 1e-6:
		side = right * SKID_WIDTH * 0.5
	var quad := PackedVector3Array([a - side, a + side, b + side, b - side])
	if _segments.size() < MAX_SEGMENTS:
		_segments.append(quad)
		_alphas.append(amount)
	else:
		_segments[_next] = quad
		_alphas[_next] = amount
		_next = (_next + 1) % MAX_SEGMENTS
	_dirty = true


func _rebuild_skids() -> void:
	_dirty = false
	_skid_mesh.clear_surfaces()
	if _segments.is_empty():
		return
	_skid_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var ink := MangaArt.INK
	for k in _segments.size():
		var q := _segments[k]
		var col := Color(ink.r, ink.g, ink.b, 0.35 + 0.5 * _alphas[k])
		for idx in [0, 1, 2, 0, 2, 3]:
			_skid_mesh.surface_set_color(col)
			_skid_mesh.surface_add_vertex(q[idx])
	_skid_mesh.surface_end()


func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.1
	p.local_coords = false
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := ShaderMaterial.new()
	m.shader = SMOKE_SHADER
	quad.material = m
	p.mesh = quad
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, 0.5, 0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.7))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	add_child(p)
	return p


func _make_sparks(amount: int, explosiveness: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.35
	p.explosiveness = explosiveness
	p.local_coords = false
	p.emitting = false
	var streak := QuadMesh.new()
	streak.size = Vector2(0.045, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.62, 0.14)
	streak.material = m
	p.mesh = streak
	p.particle_flag_align_y = true
	p.spread = 40.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0, -9.8, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.55))
	ramp.set_color(1, Color(1.0, 0.3, 0.04, 0.0))
	p.color_ramp = ramp
	add_child(p)
	return p


func _on_wall_contact(point: Vector3, normal: Vector3, dv: float, slide: float) -> void:
	var fx: float = MangaArt.fx_intensity()
	# Scrapes: sparks while sliding along a wall or rail.
	if slide > 4.0:
		_scrape_timer = 0.12
		# Out from the contact and up, so the spray clears the body and reads from the chase cam.
		_sparks.global_position = point + normal * 0.15 + Vector3.UP * 0.25
		var along := car.linear_velocity - normal * car.linear_velocity.dot(normal)
		_sparks.direction = (along.normalized() * -0.6 + normal * 0.5 + Vector3.UP * 0.6).normalized()
	# Hits: a spark burst, an impact frame and camera trauma, scaled by the impulse.
	if dv > 3.0:
		var severity := clampf((dv - 3.0) / 7.0, 0.25, 1.0) * fx
		_burst.global_position = point
		_burst.direction = (normal + Vector3.UP * 0.5).normalized()
		_burst.restart()
		if camera:
			camera.add_impact(severity)
