class_name RoadsideLife
extends Node3D
## Life on Pass 1, built at runtime: a tricycle shuttling through the barangay, a motorcycle riding
## up the pass the other way, and an askal patrolling the shoulder by the sari-sari store. The
## vehicles are kinematic bodies cars can hit; they keep to the edge of the road and pull onto the
## shoulder and slow when a car comes at them, as PH tricycles do, and stand down during races.
## The dog has no collision.

## Tricycle shuttle span (metres after the start line) and the dog's patrol by the store.
const TRICYCLE := preload("res://assets/vehicles/traffic/tricycle.glb")
const MOTORCYCLE := preload("res://assets/vehicles/traffic/motorcycle.glb")
## Nothing may stick out past this far from the road centre (the paved shoulder ends at 3.3 m;
## rails and the gutter start just beyond).
const ROAD_EDGE := 3.25
const TRIKE_SPAN := Vector2(45.0, 330.0)
const DOG_SPAN := Vector2(48.0, 62.0)
const YIELD_RANGE := 55.0

var track: TrackData
## True while a timed run or VS race is on: the traffic stands down (hidden, no collision) so it
## never decides a race. It rides in free drive. (The racing AI does not avoid traffic yet.)
var racing: Callable = func() -> bool: return false

var _movers: Array[Mover] = []
var _dog: Dog


func _ready() -> void:
	var s := track.start_distance
	var trike := Mover.new()
	trike.name = "Tricycle"
	trike.track = track
	trike.span = Vector2(s + TRIKE_SPAN.x, s + TRIKE_SPAN.y)
	trike.speed = 7.0
	trike.lane = 2.8
	trike.shoulder = ROAD_EDGE
	trike.distance = s + 150.0
	trike.dir = -1
	trike.ping_pong = true
	trike.setup(TRICYCLE, Color(0.1, 0.32, 0.75), 0.32)
	add_child(trike)
	_movers.append(trike)
	var moto := Mover.new()
	moto.name = "Motorcycle"
	moto.track = track
	moto.span = Vector2(s + 340.0, track.finish_distance - 30.0)
	moto.speed = 12.0
	moto.lane = 2.2
	moto.shoulder = 3.0
	moto.distance = s + 900.0
	moto.dir = -1
	moto.setup(MOTORCYCLE, Color(0.85, 0.55, 0.05), 0.39)
	add_child(moto)
	_movers.append(moto)
	_dog = Dog.new()
	_dog.name = "Askal"
	_dog.track = track
	_dog.span = Vector2(s + DOG_SPAN.x, s + DOG_SPAN.y)
	add_child(_dog)


func _physics_process(delta: float) -> void:
	var cars := get_tree().get_nodes_in_group(&"cars")
	var stand_down: bool = racing.call()
	for m in _movers:
		if m.visible == stand_down:
			m.visible = not stand_down
			m.collision_layer = 0 if stand_down else CarBody.STATIC_LAYER
		if not stand_down:
			m.step(delta, cars)
	_dog.step(delta)


# --- Movers ------------------------------------------------------------------------------------

## A vehicle following the road on the side of its travel (PH drives on the right), at walking-
## pace-to-moped speeds. One-way movers loop back out of sight; ping-pong movers U-turn at the
## ends of their span. `lane` / `shoulder` are where its outer (right-hand) edge runs, normally
## and when yielding; whatever its pose, no part of it leaves the paved road (ROAD_EDGE).
class Mover extends AnimatableBody3D:
	var track: TrackData
	var span := Vector2.ZERO
	var speed := 8.0
	var lane := 2.8
	var shoulder := 3.25
	var distance := 0.0
	## +1 downhill (with the race), -1 uphill (oncoming).
	var dir := -1
	var ping_pong := false
	var wheels: Array[Node3D] = []
	var lamps: Array[SpotLight3D] = []
	var lamp_faces: Array[ShaderMaterial] = []
	var wheel_radius := 0.3
	var _lateral := 2.0
	var _speed := 0.0
	var _turn := 0.0   # 0..1 while turning around
	## The body's footprint in mover space (x right, z back), for keeping it on the road.
	var _footprint := AABB()

	## Builds the vehicle from a traffic GLB (tools/vehicle_builders/build-roadside-traffic.py):
	## manga materials with `paint` in the given colour, spinning `wheel_*` nodes, a head lamp
	## (beam at night), and a box collider over the body.
	func setup(scene: PackedScene, paint: Color, radius: float) -> void:
		wheel_radius = radius
		var model: Node3D = scene.instantiate()
		# The GLB faces +Z; movers drive toward -Z.
		model.rotation.y = PI
		add_child(model)
		var mats := MangaArt.apply_car(model, paint)
		for key in ["headlight", "taillight"]:
			if mats.has(key):
				lamp_faces.append(mats[key])
		for n in model.find_children("wheel_*", "Node3D", true, false):
			wheels.append(n as Node3D)
		var body := model.find_child("body", true, false) as MeshInstance3D
		var to_mover := model.transform * body.transform
		_footprint = to_mover * body.get_aabb()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = _footprint.size
		shape.shape = bs
		shape.position = _footprint.get_center()
		add_child(shape)
		var head := model.find_child("headlight", true, false) as Node3D
		var at := model.transform * head.position if head else Vector3(_footprint.get_center().x, _footprint.position.y + _footprint.size.y * 0.55, _footprint.position.z)
		var spot := SpotLight3D.new()
		spot.light_color = MangaArt.HEADLAMP
		spot.spot_range = 22.0
		spot.spot_angle = 24.0
		spot.spot_attenuation = 0.5
		spot.spot_angle_attenuation = 0.3
		spot.light_specular = 0.22
		spot.shadow_enabled = false
		spot.visible = false
		spot.position = at + Vector3(0, 0, -0.1)
		spot.rotation = Vector3(-0.16, 0.0, 0.0)
		add_child(spot)
		lamps.append(spot)

	func _ready() -> void:
		sync_to_physics = false
		collision_layer = CarBody.STATIC_LAYER
		collision_mask = 0
		_lateral = lane - _footprint.end.x
		_speed = speed
		_place()

	func step(delta: float, cars: Array) -> void:
		var night := MangaArt.night
		for l in lamps:
			l.visible = night > 0.02
			l.light_energy = 1.4 * night
		for f in lamp_faces:
			f.set_shader_parameter("glow", night * 1.2)
		if _turn > 0.0:
			_turn = maxf(_turn - delta / 2.5, 0.0)
			_place()
			return
		# Yield: a car coming at us (ahead along our travel, within the road's width) → shoulder.
		var yield_to := false
		var ahead := -global_basis.z
		for c in cars:
			var rel: Vector3 = (c as Node3D).global_position - global_position
			var along := rel.dot(ahead)
			if along > -4.0 and along < RoadsideLife.YIELD_RANGE and absf(rel.dot(global_basis.x)) < 12.0 and absf(rel.y) < 6.0:
				yield_to = true
		# Centre so the right-hand edge runs at lane (or shoulder when yielding).
		_lateral = move_toward(_lateral, (shoulder if yield_to else lane) - _footprint.end.x, delta * 1.4)
		_speed = move_toward(_speed, speed * (0.35 if yield_to else 1.0), delta * 4.0)
		distance += dir * _speed * delta
		if distance < span.x or distance > span.y:
			if ping_pong:
				distance = clampf(distance, span.x, span.y)
				dir = -dir
				_turn = 1.0
			elif _out_of_sight(cars):
				distance = span.y if dir < 0 else span.x
			else:
				distance = clampf(distance, span.x, span.y)
				_speed = 0.0
		for w in wheels:
			# The model is turned around, so the wheel's +X is our -X: positive rolls forward.
			w.rotate_object_local(Vector3.RIGHT, _speed * delta / wheel_radius)
		_place()

	func _out_of_sight(cars: Array) -> bool:
		var far_end := track.pose_at(span.y if dir < 0 else span.x)["position"] as Vector3
		for c in cars:
			var p := (c as Node3D).global_position
			if p.distance_to(global_position) < 120.0 or p.distance_to(far_end) < 120.0:
				return false
		return true

	func _place() -> void:
		var i := track.index_at(distance)
		var j := mini(i + 1, track.points.size() - 1)
		var t := clampf(distance / track.spacing - i, 0.0, 1.0)
		var p := track.points[i].lerp(track.points[j], t)
		var r := track.rights[i].lerp(track.rights[j], t).normalized()
		var f := track.forwards[i].lerp(track.forwards[j], t).normalized() * dir
		# Drive on the right of our travel: downhill that is +right, uphill -right.
		var pos := p + r * _lateral * dir + Vector3.UP * 0.02
		var face := f
		if _turn > 0.0:
			# Swing around through the road's width in a U-turn.
			var a := PI * (1.0 - _turn)
			face = (-f).rotated(Vector3.UP, a * (1.0 if dir > 0 else -1.0))
			pos = p + r * _lateral * dir * cos(a)
		var basis := Basis.looking_at(Vector3(face.x, 0.0, face.z).normalized(), Vector3.UP)
		# Keep every corner of the footprint on the paved road.
		var r_flat := Vector3(r.x, 0.0, r.z).normalized()
		var lo := INF
		var hi := -INF
		for k in 4:
			var corner := Vector3(_footprint.position.x if k % 2 == 0 else _footprint.end.x, 0.0, _footprint.position.z if k < 2 else _footprint.end.z)
			var lat := (pos + basis * corner - p).dot(r_flat)
			lo = minf(lo, lat)
			hi = maxf(hi, lat)
		if hi > RoadsideLife.ROAD_EDGE:
			pos -= r_flat * (hi - RoadsideLife.ROAD_EDGE)
		elif lo < -RoadsideLife.ROAD_EDGE:
			pos += r_flat * (-RoadsideLife.ROAD_EDGE - lo)
		global_transform = Transform3D(basis, pos)


# --- Models ------------------------------------------------------------------------------------

static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _part(parent, bm, pos, mat)


# --- Dog ---------------------------------------------------------------------------------------

## An askal: trots along the shoulder, stops to sit and look around, wags, turns back.
class Dog extends Node3D:
	var track: TrackData
	var span := Vector2.ZERO
	var lateral := -4.0
	var _d := 0.0
	var _dir := 1
	var _pause := 0.0
	var _phase := 0.0
	var _legs: Array[Node3D] = []
	var _tail: Node3D
	var _head: Node3D
	var _body: Node3D
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.seed = 77
		_d = (span.x + span.y) * 0.5
		var fur := MangaArt.world_preset("trunk")
		var light := MangaArt.world_preset("concrete")
		_body = Node3D.new()
		add_child(_body)
		RoadsideLife._box(_body, Vector3(0.24, 0.24, 0.62), Vector3(0, 0.42, 0), light)
		_head = Node3D.new()
		_head.position = Vector3(0, 0.55, -0.34)
		_body.add_child(_head)
		RoadsideLife._box(_head, Vector3(0.2, 0.2, 0.22), Vector3(0, 0.02, -0.05), light)
		RoadsideLife._box(_head, Vector3(0.11, 0.1, 0.14), Vector3(0, -0.03, -0.2), fur)
		for x in [-0.07, 0.07]:
			var ear := RoadsideLife._box(_head, Vector3(0.05, 0.12, 0.04), Vector3(x, 0.15, 0.0), fur)
			ear.rotation.z = x * 3.0
		_tail = Node3D.new()
		_tail.position = Vector3(0, 0.5, 0.31)
		_body.add_child(_tail)
		RoadsideLife._box(_tail, Vector3(0.05, 0.05, 0.28), Vector3(0, 0.08, 0.12), fur).rotation.x = 0.7
		for p in [Vector3(-0.08, 0.32, -0.22), Vector3(0.08, 0.32, -0.22), Vector3(-0.08, 0.32, 0.22), Vector3(0.08, 0.32, 0.22)]:
			var hip := Node3D.new()
			hip.position = p
			_body.add_child(hip)
			RoadsideLife._box(hip, Vector3(0.06, 0.32, 0.06), Vector3(0, -0.16, 0), fur)
			_legs.append(hip)

	func step(delta: float) -> void:
		_phase += delta
		var walking := _pause <= 0.0
		if walking:
			_d += _dir * 1.1 * delta
			if _d > span.y or _d < span.x or _rng.randf() < delta * 0.12:
				_pause = _rng.randf_range(2.5, 6.0)
				_d = clampf(_d, span.x, span.y)
		else:
			_pause -= delta
			if _pause <= 0.0 and (_d >= span.y - 0.5 or _d <= span.x + 0.5 or _rng.randf() < 0.4):
				_dir = -_dir
		# Legs swing in a trot; sitting tucks the hind legs and drops the rear.
		for k in _legs.size():
			var sign := 1.0 if k == 0 or k == 3 else -1.0
			_legs[k].rotation.x = sin(_phase * 9.0) * 0.5 * sign if walking else (0.0 if k < 2 else -1.2)
		_body.rotation.x = 0.0 if walking else -0.32
		_body.position.y = 0.0 if walking else -0.08
		_tail.rotation.y = sin(_phase * (14.0 if not walking else 6.0)) * 0.6
		_head.rotation.y = 0.0 if walking else sin(_phase * 0.7) * 0.8
		var pose := track.pose_at(_d, lateral)
		var i := track.index_at(_d)
		var f := track.forwards[i] * _dir
		var pos: Vector3 = pose["position"] - Vector3.UP * 0.3 + Vector3.UP * (absf(sin(_phase * 9.0)) * 0.03 if walking else 0.0)
		global_transform = Transform3D(Basis.looking_at(Vector3(f.x, 0.0, f.z).normalized(), Vector3.UP), pos)
