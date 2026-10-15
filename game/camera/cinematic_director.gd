class_name CinematicDirector
extends Node
## Auto-directed TV/replay camera, in the spirit of an Assetto Corsa replay or GTA's cinematic
## view. Hard cuts every few seconds between trackside telephoto cams, fly-bys, a low chase, a
## helicopter, a drone, car-mounted wheel and nose shots and a slow orbit. It prefers whichever
## cars are battling. `ChaseCamera` hands it the camera in its CINEMATIC mode.

enum Shot { TRACKSIDE, FLYBY, CHASE_LOW, HELI, DRONE, WHEEL, NOSE, ORBIT, LEAD }
const SHOT_NAMES := ["TRACKSIDE", "FLYBY", "CHASE LOW", "HELI", "DRONE", "WHEEL", "NOSE", "ORBIT", "LEAD"]
## Relative odds of each shot at a cut.
const WEIGHTS := { Shot.TRACKSIDE: 5.0, Shot.FLYBY: 2.0, Shot.CHASE_LOW: 2.0, Shot.HELI: 1.5, Shot.DRONE: 1.5,
	Shot.WHEEL: 1.5, Shot.NOSE: 1.0, Shot.ORBIT: 1.0, Shot.LEAD: 1.5 }
## Cars this close (m) are a battle worth cutting to.
const BATTLE_GAP := 28.0
const LETTERBOX := 0.11
const ORBIT_RADIUS := 6.5

var track: TrackData
var cars: Array[CarBody] = []
var names: Array[String] = []
## Index into `cars` the camera follows.
var focus := 0
## Pick the focus at each cut (battles first); off once the viewer picks a car.
var auto_focus := true
## Show the bars (ChaseCamera sets this from its mode).
var active := false:
	set(v):
		active = v
		if not v:
			_shot_time = 0.0

var shot := Shot.CHASE_LOW
var _shot_time := 0.0
var _shot_length := 5.0
var _anchor := Vector3.ZERO      # fixed cams: where the camera stands
var _side := 1.0
var _angle := 0.0
var _passed := false
var _pos := Vector3.ZERO
var _fov := 50.0
var _rng := RandomNumberGenerator.new()
var _bars: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _bar_t := 0.0
var _space: PhysicsDirectSpaceState3D
var _hidden := 0.0


func _ready() -> void:
	_rng.randomize()
	_bars = CanvasLayer.new()
	_bars.layer = 8
	add_child(_bars)
	for preset in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE]:
		var r := ColorRect.new()
		r.color = MangaType.INK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(preset)
		_bars.add_child(r)
		if preset == Control.PRESET_TOP_WIDE:
			_top = r
		else:
			_bottom = r


func set_cars(cars_: Array, names_: Array) -> void:
	cars.assign(cars_)
	names.assign(names_)
	focus = clampi(focus, 0, maxi(0, cars.size() - 1))
	_shot_time = 0.0


func focus_car() -> CarBody:
	if cars.is_empty():
		return null
	focus = clampi(focus, 0, cars.size() - 1)
	return cars[focus] if is_instance_valid(cars[focus]) else null


## Cut to a new shot on the next update.
func cut() -> void:
	_shot_time = 0.0


func _process(delta: float) -> void:
	# Bars ease in and out on real time, so they still move in a paused or slowed replay.
	var real := delta / maxf(Engine.time_scale, 0.001)
	_bar_t = move_toward(_bar_t, 1.0 if active else 0.0, real * 2.5)
	var h := get_viewport().get_visible_rect().size.y * LETTERBOX * smoothstep(0.0, 1.0, _bar_t)
	_top.offset_bottom = h
	_bottom.offset_top = -h
	_bars.visible = _bar_t > 0.0


## Place `cam` for this frame. Returns the car in shot (for speed lines), or null.
func update(cam: Camera3D, delta: float) -> CarBody:
	var car := focus_car()
	if car == null:
		return null
	_space = cam.get_world_3d().direct_space_state
	_shot_time -= delta
	if _shot_time <= 0.0 or _shot_over(car):
		_new_shot(car)
		car = focus_car()
		_place(cam, car, 1.0, true)
		return car
	_place(cam, car, delta, false)
	# Lost the car behind the hillside: give it a moment, then cut away.
	_hidden = _hidden + delta if _blocked(cam.global_position, car.global_position + Vector3.UP * 0.7) else 0.0
	if _hidden > 0.35:
		_hidden = 0.0
		_shot_time = 0.0
	return car


## Speed lines suit the shots that ride with the car, not the static or distant ones.
func speed_lines() -> bool:
	return shot in [Shot.CHASE_LOW, Shot.DRONE, Shot.WHEEL, Shot.NOSE, Shot.LEAD]


func _shot_over(car: CarBody) -> bool:
	if shot != Shot.TRACKSIDE and shot != Shot.FLYBY:
		return false
	var p := car.global_position
	var ahead := (_anchor - p).dot(_travel(car)) > 0.0
	if not ahead and not _passed:
		_passed = true
		_shot_time = minf(_shot_time, 1.6 if shot == Shot.FLYBY else 3.0)
	return p.distance_to(_anchor) > 160.0


func _new_shot(car: CarBody) -> void:
	if auto_focus:
		_pick_focus()
	car = focus_car()
	var last := shot
	var total := 0.0
	for s in WEIGHTS:
		if s != last:
			total += WEIGHTS[s]
	var roll := _rng.randf() * total
	for s in WEIGHTS:
		if s == last:
			continue
		roll -= WEIGHTS[s]
		if roll <= 0.0:
			shot = s
			break
	_shot_length = _rng.randf_range(4.0, 7.0)
	_side = -1.0 if _rng.randf() < 0.5 else 1.0
	_angle = _rng.randf() * TAU
	_passed = false
	if shot == Shot.ORBIT:
		# Start where the hillside does not hide the car.
		var p := car.global_position + Vector3.UP * 0.7
		for i in 8:
			var a := _angle + i * TAU / 8.0
			var eye := p + Vector3(cos(a), 0.0, sin(a)) * ORBIT_RADIUS + Vector3.UP * 0.4
			if not _blocked(eye, p) and _ground(eye) < eye.y - 0.5:
				_angle = a
				break
	if shot == Shot.TRACKSIDE or shot == Shot.FLYBY:
		_shot_length = 12.0
		if not _find_anchor(car):
			shot = Shot.CHASE_LOW
			_shot_length = 5.0
	_shot_time = _shot_length


## Battles first: the closest pair on the road, shot from the chasing car's side. Otherwise
## a different car now and then so every driver gets screen time.
func _pick_focus() -> void:
	var best := -1
	var best_gap := BATTLE_GAP
	for i in cars.size():
		for j in cars.size():
			if i == j or not is_instance_valid(cars[i]) or not is_instance_valid(cars[j]):
				continue
			var gap := cars[i].global_position.distance_to(cars[j].global_position)
			if gap < best_gap and cars[i].linear_velocity.length() > 5.0:
				best_gap = gap
				best = i
	if best >= 0:
		focus = best
	elif cars.size() > 1 and _rng.randf() < 0.3:
		focus = _rng.randi() % cars.size()


## A trackside spot ahead of the car with a clear view of the road: TV cams stand back on
## a long lens, fly-bys stand right at the edge.
func _find_anchor(car: CarBody) -> bool:
	if track == null:
		return false
	var i := track.nearest_index(car.global_position)
	var d := i * track.spacing
	var speed := maxf(car.linear_velocity.length(), 8.0)
	for attempt in 6:
		var ahead := (_rng.randf_range(2.5, 4.5) if shot == Shot.TRACKSIDE else _rng.randf_range(1.6, 2.4)) * speed
		var lateral := track.half_width + (_rng.randf_range(3.0, 9.0) if shot == Shot.TRACKSIDE else _rng.randf_range(0.8, 1.6))
		var side := _side if attempt % 2 == 0 else -_side
		var pose := track.pose_at(minf(d + ahead, track.length() - 1.0), side * lateral)
		var base: Vector3 = pose["position"]
		var ground := _ground(base)
		var lift := _rng.randf_range(1.5, 5.0) if shot == Shot.TRACKSIDE else _rng.randf_range(0.5, 1.0)
		var spot := Vector3(base.x, ground + lift, base.z)
		var road: Vector3 = track.pose_at(minf(d + ahead * 0.5, track.length() - 1.0))["position"]
		if not _blocked(spot, road + Vector3.UP * 0.8) and not _blocked(spot, car.global_position + Vector3.UP * 0.8):
			_anchor = spot
			return true
	return false


func _place(cam: Camera3D, car: CarBody, delta: float, snap: bool) -> void:
	var xf := car.get_global_transform_interpolated()
	var p := xf.origin + Vector3.UP * 0.6
	var f := _travel(car)
	var r := f.cross(Vector3.UP).normalized()
	var speed := car.linear_velocity.length()
	var k := 1.0 if snap else 1.0 - exp(-4.0 * delta)
	var look := p
	var fov := 50.0
	match shot:
		Shot.TRACKSIDE:
			_pos = _anchor
			# Keep the car about the same size in frame: a long lens when far, wider when close.
			var dist := _anchor.distance_to(p)
			fov = clampf(rad_to_deg(2.0 * atan(7.0 / maxf(dist, 1.0))), 7.0, 50.0)
			look = p + f * minf(speed * 0.12, 2.0)
		Shot.FLYBY:
			_pos = _anchor
			fov = 64.0
		Shot.CHASE_LOW:
			_pos = _pos.lerp(p - f * 4.6 + Vector3.UP * 0.15 + r * 0.9 * _side, k)
			look = p + f * 8.0
			fov = 58.0 + clampf(speed * 0.2, 0.0, 10.0)
		Shot.HELI:
			_angle += delta * 0.08
			var around := (-f).rotated(Vector3.UP, 0.7 * _side + sin(_angle) * 0.3)
			_pos = _pos.lerp(p + around * 22.0 + Vector3.UP * 15.0, 1.0 if snap else 1.0 - exp(-1.5 * delta))
			fov = 30.0
		Shot.DRONE:
			_pos = _pos.lerp(p - f * 9.0 + Vector3.UP * 6.5 + r * 2.0 * _side, 1.0 if snap else 1.0 - exp(-2.5 * delta))
			look = p + f * 10.0
			fov = 55.0
		Shot.WHEEL:
			# Low on the flank by the rear wheel, looking up the side of the car.
			_pos = xf * Vector3(1.3 * _side, 0.35, 1.9)
			look = xf * Vector3(0.6 * _side, 0.5, -3.0)
			fov = 72.0
		Shot.NOSE:
			# Ahead of the bumper looking back at the car, a little off centre.
			_pos = xf * Vector3(1.0 * _side, 0.7, -6.0)
			look = xf * Vector3(0.0, 0.6, 0.3)
			fov = 46.0
		Shot.ORBIT:
			_angle += delta * 0.45
			_pos = p + Vector3(cos(_angle), 0.0, sin(_angle)) * ORBIT_RADIUS + Vector3.UP * 1.0
			fov = 48.0
		Shot.LEAD:
			# Tracking ahead of the car, pulled along the road, the car chasing the lens.
			_pos = _pos.lerp(p + f * (11.0 + speed * 0.2) + Vector3.UP * 1.1 + r * 1.4 * _side,
				1.0 if snap else 1.0 - exp(-8.0 * delta))
			fov = 40.0
	if shot != Shot.WHEEL and shot != Shot.NOSE and shot != Shot.TRACKSIDE and shot != Shot.FLYBY:
		_pos.y = maxf(_pos.y, _ground(_pos) + 0.45)
	_fov = fov if snap else lerpf(_fov, fov, 1.0 - exp(-3.0 * delta))
	cam.global_position = _pos
	cam.fov = _fov
	if not _pos.is_equal_approx(look):
		var up := Vector3.UP if absf((look - _pos).normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		cam.look_at(look, up)


func _travel(car: CarBody) -> Vector3:
	var v := car.linear_velocity
	v.y = 0.0
	var nose := -car.global_basis.z
	nose.y = 0.0
	return v.normalized() if v.length() > 3.0 else nose.normalized()


func _ground(p: Vector3) -> float:
	if _space == null:
		return p.y
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 120.0, CarBody.STATIC_LAYER)
	var hit := _space.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else p.y


func _blocked(from: Vector3, to: Vector3) -> bool:
	if _space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, to, CarBody.STATIC_LAYER)
	return not _space.intersect_ray(q).is_empty()
