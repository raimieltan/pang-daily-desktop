class_name CarFx
extends Node3D
## World-space driving effects, all driven by the sim (docs/ART_DIRECTION.md §4):
## ink skid marks and manga cloud smoke from per-wheel slip, yellow-orange sparks from wall
## scrapes, and impact frames + camera trauma from hard hits. Exhaust puffs on throttle and a
## pop with a flame lick on lift-off from high revs; a burst radiator hose (steam gushing from
## the hood) after a hard frontal hit, or on demand (`burst_steam`). Lives outside the car so
## marks and particles stay in the world.

const SMOKE_SHADER := preload("res://game/art/manga_smoke.gdshader")
const MAX_SEGMENTS := 2400
const SKID_WIDTH := 0.19
const SKID_STEP := 0.35
## Slip that starts marking: slip angle (rad) or slip ratio.
const SLIDE_ANGLE := 0.14
const SLIDE_RATIO := 0.22

var car: CarBody
var camera: ChaseCamera

var _skid_mesh := ArrayMesh.new()
var _skid_verts := PackedVector3Array()
var _skid_colors := PackedColorArray()
var _skid_instance := MeshInstance3D.new()
var _next := 0
var _dirty := false
var _last_point: Array = [null, null, null, null]
var _smoke: Array[CPUParticles3D] = []
var _sparks: CPUParticles3D
var _burst: CPUParticles3D
var _scrape_timer := 0.0
var _exhaust: CPUParticles3D
var _flame: MeshInstance3D
var _flame_time := 0.0
var _steam: CPUParticles3D
var _steam_time := 0.0
var _floored := 0.0
## Car-space spots (body faces -Z): tailpipe tip and the front of the hood.
var _pipe := Vector3(0.45, 0.3, 2.2)
var _hood := Vector3(0.0, 0.9, -1.4)


func _ready() -> void:
	top_level = true
	_skid_instance.mesh = _skid_mesh
	_skid_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var skid_mat := StandardMaterial3D.new()
	skid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skid_mat.vertex_color_use_as_albedo = true
	skid_mat.render_priority = -1
	# The strip's winding depends on travel direction; draw both faces.
	skid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_skid_instance.material_override = skid_mat
	# Marks span the whole run; skip per-frame culling work on a mesh that is always nearby.
	_skid_instance.extra_cull_margin = 1000.0
	add_child(_skid_instance)
	for i in 4:
		_smoke.append(_make_smoke())
	_sparks = _make_sparks(36, 0.1)
	_burst = _make_sparks(18, 0.95)
	_burst.one_shot = true
	_exhaust = _make_puffs(10, 0.7, 0.25, 0.45)
	_steam = _make_puffs(90, 1.2, 0.4, 1.1)
	_steam.initial_velocity_min = 1.2
	_steam.initial_velocity_max = 2.6
	_steam.damping_min = 1.5
	_steam.damping_max = 2.5
	_steam.spread = 35.0
	_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_steam.emission_box_extents = Vector3(0.35, 0.05, 0.25)
	_flame = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.12
	cone.height = 0.6
	cone.radial_segments = 8
	cone.material = MangaArt.lamp(Color(1.0, 0.55, 0.1), 1.6)
	_flame.mesh = cone
	_flame.visible = false
	add_child(_flame)
	if car:
		car.wall_contact.connect(_on_wall_contact)
		_fit_spots.call_deferred()


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
	_update_exhaust(delta, speed)
	_update_steam(delta)


## Tailpipe and hood spots. The tailpipe is the car's own exhaust tip: the `chrome` faces at the
## low rear of the body (every car model has one); the visible bounds are the fallback.
func _fit_spots() -> void:
	var box := AABB()
	var first := true
	var inv := car.global_transform.affine_inverse()
	for m in car.find_children("*", "MeshInstance3D", true, false):
		var vi := m as MeshInstance3D
		if vi.mesh == null or not vi.is_visible_in_tree():
			continue
		var b := inv * vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	_pipe = Vector3(box.position.x + box.size.x * 0.72, box.position.y + box.size.y * 0.22, box.end.z - 0.05)
	var tip := _chrome_tip(box)
	if tip != Vector3.INF:
		_pipe = tip
	_hood = Vector3(0.0, box.position.y + box.size.y * 0.68, box.position.z + box.size.z * 0.2)


## Centre of the chrome vertices in the rear 12% and lower 40% of `box` (car space, +Z behind),
## nudged to the rearmost of them; INF if the model has none there.
func _chrome_tip(box: AABB) -> Vector3:
	var inv := car.global_transform.affine_inverse()
	var acc := Vector3.ZERO
	var n := 0
	var rear := -INF
	for m in car.find_children("*", "MeshInstance3D", true, false):
		var vi := m as MeshInstance3D
		if vi.mesh == null or not vi.is_visible_in_tree():
			continue
		var xf := inv * vi.global_transform
		for i in vi.mesh.get_surface_count():
			var mat := vi.mesh.surface_get_material(i)
			if mat == null or mat.resource_name != "chrome":
				continue
			for v in vi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = xf * v
				if p.z > box.end.z - box.size.z * 0.12 and p.y < box.position.y + box.size.y * 0.4:
					acc += p
					n += 1
					rear = maxf(rear, p.z)
	if n == 0:
		return Vector3.INF
	var tip := acc / n
	tip.z = rear
	return tip


func _update_exhaust(delta: float, speed: float) -> void:
	var s := car.model.state
	var rpm := car.model.mechanics.engine_rpm
	var xf := car.global_transform
	_exhaust.global_position = xf * _pipe
	# Puffs blow back out of the pipe and get left behind.
	_exhaust.direction = xf.basis.z.normalized()
	_exhaust.emitting = s.throttle > 0.3 and speed < 25.0
	# Lift-off from high revs: a pop and a flame lick (the pedal ramps, so: was floored lately).
	_floored = 0.4 if s.throttle > 0.7 else maxf(_floored - delta, 0.0)
	if _floored > 0.0 and s.throttle < 0.15 and rpm > 4800.0:
		_floored = 0.0
		_flame_time = 0.12
		_exhaust.restart()
		_exhaust.emitting = true
	_flame_time = maxf(_flame_time - delta, 0.0)
	_flame.visible = _flame_time > 0.0
	if _flame.visible:
		# Cone tip out the back (+Z is behind the car).
		_flame.global_transform = Transform3D(xf.basis * Basis(Vector3.RIGHT, PI / 2.0), xf * (_pipe + Vector3(0, 0, 0.3)))


## Steam from a burst radiator hose, for `seconds`.
func burst_steam(seconds := 6.0) -> void:
	_steam_time = seconds


func _update_steam(delta: float) -> void:
	_steam_time = maxf(_steam_time - delta, 0.0)
	_steam.emitting = _steam_time > 0.0
	if _steam.emitting:
		var xf := car.global_transform
		_steam.global_position = xf * _hood
		# Up out of the hood seam, swept back by the car's motion.
		_steam.direction = (Vector3.UP * 2.0 + xf.basis.z * clampf(car.linear_velocity.length() / 10.0, 0.0, 1.5)).normalized()


func _process(_delta: float) -> void:
	if _dirty:
		_rebuild_skids()


## Forget where each tire last laid rubber, so the next skid starts fresh (after a teleport).
func reset_trails() -> void:
	_last_point = [null, null, null, null]


func _add_segment(a: Vector3, b: Vector3, right: Vector3, amount: float) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP).normalized() * SKID_WIDTH * 0.5
	if side.length_squared() < 1e-6:
		side = right * SKID_WIDTH * 0.5
	var ink := MangaArt.INK
	var col := Color(ink.r, ink.g, ink.b, 0.55 + 0.4 * amount)
	var quad := [a - side, a + side, b + side, a - side, b + side, b - side]
	# Ring buffer of 6 vertices per segment, written in place once full.
	var base := _skid_verts.size()
	if _segments_count() >= MAX_SEGMENTS:
		base = _next * 6
		_next = (_next + 1) % MAX_SEGMENTS
		for k in 6:
			_skid_verts[base + k] = quad[k]
			_skid_colors[base + k] = col
	else:
		for k in 6:
			_skid_verts.append(quad[k])
			_skid_colors.append(col)
	_dirty = true


func _segments_count() -> int:
	return _skid_verts.size() / 6


## One native call per rebuild (only on frames that added marks).
func _rebuild_skids() -> void:
	_dirty = false
	_skid_mesh.clear_surfaces()
	if _skid_verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _skid_verts
	arrays[Mesh.ARRAY_COLOR] = _skid_colors
	_skid_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


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


## Manga cloud puffs (the smoke shader), `size` to `grow` × size over their life.
func _make_puffs(amount: int, lifetime: float, size: float, grow: float) -> CPUParticles3D:
	var p := _make_smoke()
	p.amount = amount
	p.lifetime = lifetime
	p.spread = 15.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.8, 0)
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, grow * 2.0))
	p.scale_amount_curve = curve
	return p


func _make_sparks(amount: int, explosiveness: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.22
	p.explosiveness = explosiveness
	p.local_coords = false
	p.emitting = false
	var streak := QuadMesh.new()
	streak.size = Vector2(0.018, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.62, 0.14)
	streak.material = m
	p.mesh = streak
	p.particle_flag_align_y = true
	p.spread = 30.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
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
	# A hard hit to the nose bursts a radiator hose.
	if dv > 9.0 and normal.dot(car.global_basis.z) > 0.5:
		burst_steam(8.0)
	if dv > 3.0:
		var severity := clampf((dv - 3.0) / 7.0, 0.25, 1.0) * fx
		_burst.global_position = point
		_burst.direction = (normal + Vector3.UP * 0.5).normalized()
		_burst.restart()
		if camera:
			camera.add_impact(severity)
