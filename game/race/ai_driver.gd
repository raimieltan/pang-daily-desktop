class_name AiDriver
extends RefCounted
## A rival's driver: pure pursuit on its lane of the road, a speed plan from the curvature ahead,
## and a little rubber band so battles stay close. Feeds a CarBody's `input_source`.

const G := 9.81
## Grip the plan assumes at skill 1.0 (fresh street tires, a margin under the limit).
static var plan_mu := 0.9
static var plan_brake := 6.5
static var steer_gain := 2.8
static var throttle_steer_cut := 0.8
const STUCK_SECONDS := 2.5

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

var _index := 0
var _lane_now := 0.0
var _stuck := 0.0
var _plan: PackedFloat32Array
static var _plans := {}


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
		return VehicleTypes.DriverInput.make(0.0, 0.5, _steer(p, speed), 0.0, "ai")
	if not racing:
		return VehicleTypes.DriverInput.make(0.0, 1.0, 0.0, 0.0, "ai")
	_recover(speed, p)
	var steer := _steer(p, speed)
	# Aim at the plan half a second ahead: brakes need a moment to bite.
	var want := _plan[mini(_index + 3 + int(speed * 0.5 / track.spacing), _plan.size() - 1)] * sqrt(_effective_skill())
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


## Pure pursuit toward a point on the lane, further ahead the faster the car goes.
func _steer(p: Vector3, speed: float) -> float:
	# Lanes close up into tight corners, where the inside line is the only line.
	var corner := clampf((30.0 - _plan[_index]) / 15.0, 0.0, 1.0)
	_lane_now = move_toward(_lane_now, lane * (1.0 - 0.7 * corner), 1.5 / Engine.physics_ticks_per_second)
	var look := clampf(5.0 + speed * 0.5, 7.0, 28.0)
	var j := mini(_index + int(look / track.spacing), track.points.size() - 1)
	var target := track.points[j] + track.rights[j] * clampf(_lane_now, -track.half_width + 1.2, track.half_width - 1.2)
	var forward := -car.global_basis.z
	var right := car.global_basis.x
	var to := target - p
	var alpha := atan2(to.dot(right), to.dot(forward))
	return clampf(alpha * steer_gain, -1.0, 1.0)


func _effective_skill() -> float:
	if rival_distance < 0.0:
		return skill
	# Up to +7% when far behind the player, −5% when far ahead.
	return skill * (1.0 + clampf((rival_distance - distance) / 500.0, -0.05, 0.07))


## Back on the road if stuck against a rail or off the edge for too long.
func _recover(speed: float, p: Vector3) -> void:
	var off := absf(track.lateral_offset(p, _index)) > track.half_width + 3.0
	var backwards := car.linear_velocity.dot(track.forwards[_index]) < -1.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	_stuck = _stuck + dt * (3.0 if backwards else 1.0) if (speed < 1.5 or off or backwards) else 0.0
	if _stuck > STUCK_SECONDS:
		_stuck = 0.0
		var pose := track.pose_at(distance, clampf(lane, -1.5, 1.5))
		car.place(pose["position"], pose["heading"])
