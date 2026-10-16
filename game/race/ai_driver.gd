class_name AiDriver
extends RefCounted
## A rival's driver: pure pursuit on its lane of the road, a speed plan from the curvature ahead,
## and a little rubber band so battles stay close. Feeds a CarBody's `input_source`.
## It sees the other cars in `others`: it steers around a car in its path, holds station behind one
## it cannot get past, and gives way side by side into a tight corner when the other car is ahead.

const G := 9.81
## Grip the plan assumes at skill 1.0 (fresh street tires, a margin under the limit).
static var plan_mu := 0.9
static var plan_brake := 6.5
static var steer_gain := 2.8
static var throttle_steer_cut := 0.8
const STUCK_SECONDS := 2.5
## Also stuck if the car gains less than STUCK_PROGRESS metres of road in this long: a car pinned
## against a board can jitter above the stuck speed without going anywhere.
const STUCK_PROGRESS := 4.0
const STUCK_PROGRESS_SECONDS := 4.0
## Car-sized box for traffic (m): half a width plus a margin, and a length.
const CAR_HALF_WIDTH := 1.0
const CAR_LENGTH := 4.5
## Clearance kept beside another car when passing (m, centre to centre).
const PASS_OFFSET := 2.6
## Time gap held behind a car that cannot be passed (s), and the minimum gap (m). A car slower
## than FOLLOW_MIN_SPEED (m/s, crashed or stalled) is driven round, never followed.
const FOLLOW_TIME := 0.45
const FOLLOW_MIN := 6.0
const FOLLOW_MIN_SPEED := 5.0

var car: CarBody
var track: TrackData
## 0.8 (cautious) … 1.05 (on the limit). Scales the speed plan.
var skill := 0.92
## Preferred lateral offset from the centerline (m, right +).
var lane := 0.0
## Set by the race: false holds the brakes (grid, countdown).
var racing := false
## Past the finish: keep steering down the lane while braking to a stop.
var cooldown := false
## Distance along the road; maintained here for positions and the rubber band.
var distance := 0.0
## The player's distance, for the rubber band. Negative disables it.
var rival_distance := -1.0
## The other cars on the road (the race sets it; this driver's own car is skipped).
var others: Array = []
## Times this driver was stuck and put back on the road (probes count it).
var recoveries := 0

var _index := 0
var _lane_now := 0.0
var _stuck := 0.0
var _mark_distance := 0.0
var _mark_time := 0.0
var _plan: PackedFloat32Array
static var _plans := {}


## Game time per physics step: Engine.time_scale scales the step (probes run at 4×).
static func _dt() -> float:
	return Engine.time_scale / Engine.physics_ticks_per_second


func _init(car_: CarBody, track_: TrackData, skill_: float, lane_: float) -> void:
	car = car_
	track = track_
	skill = skill_
	lane = lane_
	_lane_now = lane_
	_plan = speed_plan(track_)


## Highest speed (m/s) at each sample for μ = plan_mu: corner limit from curvature, then a
## backward pass so the car can brake down to every corner in time. Cached per track.
static func speed_plan(t: TrackData) -> PackedFloat32Array:
	if _plans.has(t):
		return _plans[t]
	var n := t.points.size()
	var plan := PackedFloat32Array()
	plan.resize(n)
	var span := 6
	for i in n:
		var a := t.forwards[maxi(0, i - span)]
		var b := t.forwards[mini(n - 1, i + span)]
		var turn := absf(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)))
		var k := turn / (2.0 * span * t.spacing)
		plan[i] = minf(70.0, sqrt(plan_mu * G / maxf(k, 1e-4)))
	for i in range(n - 2, -1, -1):
		plan[i] = minf(plan[i], sqrt(plan[i + 1] * plan[i + 1] + 2.0 * plan_brake * t.spacing))
	_plans[t] = plan
	return plan


func input() -> VehicleTypes.DriverInput:
	var p := car.global_position
	_index = track.nearest_index(p, _index)
	distance = _index * track.spacing
	var speed := car.linear_velocity.length()
	if cooldown:
		return VehicleTypes.DriverInput.make(0.0, 0.5, _steer(p, speed, NAN), 0.0, "ai")
	if not racing:
		return VehicleTypes.DriverInput.make(0.0, 1.0, 0.0, 0.0, "ai")
	_recover(speed, p)
	var traffic := _traffic(p, speed)
	var steer := _steer(p, speed, traffic["lane"])
	# Aim at the plan half a second ahead: brakes need a moment to bite.
	var want := _plan[mini(_index + 3 + int(speed * 0.5 / track.spacing), _plan.size() - 1)] * sqrt(_effective_skill())
	want = minf(want, traffic["speed"])
	var err := want - speed
	var throttle := 0.0
	var brake := 0.0
	if err > -0.5:
		throttle = clampf(0.35 + err * 0.3, 0.0, 1.0)
		# Squeeze the throttle out of the turn: full power only once the wheel is near straight,
		# and lift if the rear steps out (the GSR sends 60% of the torque rearward).
		throttle *= clampf(1.0 - throttle_steer_cut * absf(steer), 0.25, 1.0)
		if absf(car.model.diagnostics.body_slip) > deg_to_rad(8.0):
			throttle *= 0.3
	elif err < -1.5:
		# Less brake with lock on: a braked, turned-in car swaps ends.
		brake = clampf((-err - 1.5) * 0.22, 0.1, 1.0) * (1.0 - 0.5 * absf(steer))
	return VehicleTypes.DriverInput.make(throttle, brake, steer, 0.0, "ai")


## Pure pursuit toward a point on the lane, further ahead the faster the car goes. `avoid` is a
## lane to take around traffic instead (NAN: none).
func _steer(p: Vector3, speed: float, avoid: float) -> float:
	# Lanes close up into tight corners, where the inside line is the only line.
	var corner := clampf((30.0 - _plan[_index]) / 15.0, 0.0, 1.0)
	var target_lane := lane * (1.0 - 0.7 * corner) if is_nan(avoid) else avoid
	_lane_now = move_toward(_lane_now, target_lane, (1.5 if is_nan(avoid) else 3.5) * _dt())
	var look := clampf(5.0 + speed * 0.5, 7.0, 28.0)
	var j := mini(_index + int(look / track.spacing), track.points.size() - 1)
	var target := track.points[j] + track.rights[j] * clampf(_lane_now, -track.half_width + 1.2, track.half_width - 1.2)
	var forward := -car.global_basis.z
	var right := car.global_basis.x
	var to := target - p
	var alpha := atan2(to.dot(right), to.dot(forward))
	return clampf(alpha * steer_gain, -1.0, 1.0)


## How to treat the other cars this step: { "lane": a lane to pass on (NAN: keep the racing
## lane), "speed": a speed cap (m/s, INF: none) }. Looks at cars in front within a reach that grows
## with speed, in the car's own frame (ahead along its nose, side to its right).
func _traffic(p: Vector3, speed: float) -> Dictionary:
	var out := { "lane": NAN, "speed": INF }
	if others.is_empty():
		return out
	var forward := -car.global_basis.z
	var right := car.global_basis.x
	var reach := clampf(8.0 + speed * 1.2, 12.0, 45.0)
	var my_lat := track.lateral_offset(p, _index)
	var room := track.half_width - 1.2
	var corner := clampf((30.0 - _plan[_index]) / 15.0, 0.0, 1.0)
	var nearest := INF
	for o in others:
		if o == car or not is_instance_valid(o) or not (o as Node).is_inside_tree():
			continue
		var other := o as CarBody
		var to: Vector3 = other.global_position - p
		var ahead := to.dot(forward)
		var side := to.dot(right)
		if ahead < -CAR_LENGTH or ahead > reach or absf(side) > 4.0:
			continue
		var closing := (car.linear_velocity - other.linear_velocity).dot(forward)
		var other_lat := track.lateral_offset(other.global_position, _index)
		# Who is in front is decided along the road, so two cars never both wait for each other.
		var other_index := track.nearest_index(other.global_position, _index)
		var road_ahead := (other_index - _index) * track.spacing
		var other_speed := maxf(0.0, other.linear_velocity.dot(forward))
		if ahead > CAR_LENGTH * 0.8 and road_ahead > 0.0:
			# In front. In the way if our paths overlap within the time to reach it.
			if absf(side) > 2.0 * CAR_HALF_WIDTH + 0.4 and closing < 3.0:
				continue
			if ahead >= nearest:
				continue
			nearest = ahead
			# Pass on the side with more road; if neither side fits, follow.
			var left := other_lat - PASS_OFFSET
			var rightl := other_lat + PASS_OFFSET
			var left_ok := left > -room
			var right_ok := rightl < room
			if left_ok or right_ok:
				var pick := left if (left_ok and (not right_ok or absf(left - my_lat) < absf(rightl - my_lat))) else rightl
				out["lane"] = clampf(pick, -room, room)
			# Hold station only when it matters: on its line and about to run into it, or in a
			# tight corner where there is no room to go round. Otherwise keep racing and pass.
			var on_its_line := absf(my_lat - other_lat) < 2.0 * CAR_HALF_WIDTH + 0.2
			var contact_in := (ahead - CAR_LENGTH) / closing if closing > 0.1 else INF
			var gap := maxf(FOLLOW_MIN, speed * FOLLOW_TIME)
			if on_its_line and other_speed > FOLLOW_MIN_SPEED and (contact_in < 1.2 or corner > 0.4):
				if ahead < gap * 2.0:
					out["speed"] = minf(out["speed"], other_speed + maxf(0.0, ahead - gap) * 0.6)
		elif absf(ahead) <= CAR_LENGTH * 0.8:
			# Alongside. Keep a car's width, and into a tight corner the car behind gives way.
			var away := my_lat + (PASS_OFFSET - absf(my_lat - other_lat)) * (1.0 if my_lat >= other_lat else -1.0)
			if absf(my_lat - other_lat) < PASS_OFFSET:
				out["lane"] = clampf(away, -room, room)
			if corner > 0.3 and road_ahead > 0.0 and other_speed > FOLLOW_MIN_SPEED:
				out["speed"] = minf(out["speed"], other_speed - 2.0)
	return out


func _effective_skill() -> float:
	if rival_distance < 0.0:
		return skill
	# Up to +7% when far behind the player, −5% when far ahead.
	return skill * (1.0 + clampf((rival_distance - distance) / 500.0, -0.05, 0.07))


## Back on the road if stuck against a rail or off the edge for too long.
func _recover(speed: float, p: Vector3) -> void:
	var off := absf(track.lateral_offset(p, _index)) > track.half_width + 3.0
	var backwards := car.linear_velocity.dot(track.forwards[_index]) < -1.0
	var dt := _dt()
	_stuck = _stuck + dt * (3.0 if backwards else 1.0) if (speed < 1.5 or off or backwards) else 0.0
	if distance > _mark_distance + STUCK_PROGRESS or distance < _mark_distance - 50.0:
		_mark_distance = distance
		_mark_time = 0.0
	else:
		_mark_time += dt
	if _stuck > STUCK_SECONDS or _mark_time > STUCK_PROGRESS_SECONDS:
		_stuck = 0.0
		_mark_time = 0.0
		recoveries += 1
		var pose := _clear_pose(distance + 3.0)
		car.place(pose["position"], pose["heading"])


## A spot on the road at `d` clear of the other cars: the racing lane if it is free, else the
## first free of the centre and either side.
func _clear_pose(d: float) -> Dictionary:
	var pose := {}
	for lat in [clampf(lane, -1.5, 1.5), 0.0, -1.8, 1.8]:
		pose = track.pose_at(d, lat)
		var free := true
		for o in others:
			if o != car and is_instance_valid(o) and (o as Node3D).global_position.distance_to(pose["position"]) < 3.5:
				free = false
		if free:
			return pose
	return track.pose_at(d + 6.0, clampf(lane, -1.5, 1.5))
