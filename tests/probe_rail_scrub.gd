extends SceneTree
## What leaning on a guardrail costs. Three coasting runs down the start straight of Pass 1:
## full throttle to DRIVE_SECONDS, then throttle off until END_SECONDS, speed read at the end.
##   0  down the lane, no rail;
##   1  steered onto the left rail at a shallow angle and held against it, the car's rail scrub
##      off (the engine's frictionless body alone: the rail only redirects the car);
##   2  the same lean with the scrub on.
## The rail's cost is the gap between 1 and 2 (the steering's own tire scrub is in both). Exits 0
## when the scrub costs at least SCRUB of the speed over the lean.
## `godot --headless --fixed-fps 120 --path . -s res://tests/probe_rail_scrub.gd`

const START := 25.0
const DRIVE_SECONDS := 3.0
## Before 85 m: the left rail has a gap there and the car drops off the edge.
const END_SECONDS := 4.8
const LEAN_FROM := 1.5
## Steer into the rail until it is touched, then a light lean.
const APPROACH_STEER := -0.18
const LEAN_STEER := -0.06
const SCRUB := 0.05

var _scene
var _t := 0.0
var _phase := -1
var _index := 0
var _contacts := 0
var _touched := false
var _speeds := []
var _frames := []


func _initialize() -> void:
	Engine.max_physics_steps_per_frame = 64
	GameMenu.skip_title = true
	_scene = load("res://scenes/touge.tscn").instantiate()
	root.add_child(_scene)


func _physics_process(delta: float) -> bool:
	var session: DriveSession = _scene.session
	var car: CarBody = session.car
	var track: TrackData = _scene.track
	if _phase < 0:
		_scene.time_attack.free_drive()
		car.wall_contact.connect(func(_p, _n, _dv, _s): _contacts += 1; _touched = true)
		_begin(0)
		return false
	_t += delta
	_index = track.nearest_index(car.global_position, _index)
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		print("  run %d t=%.1f d=%.0f lat=%+.1f %.0f km/h rail frames=%d" % [_phase, _t, _index * track.spacing,
			track.lateral_offset(car.global_position, _index), car.speed_kmh(), _contacts])
	if _t >= END_SECONDS:
		_speeds.append(car.speed_kmh())
		_frames.append(_contacts)
		print("%s: %.1f km/h at the end, %d frames on the rail" % [_label(_phase), car.speed_kmh(), _contacts])
		if _phase == 2:
			var lane: float = _speeds[0]
			var off: float = _speeds[1]
			var on: float = _speeds[2]
			var cost := 1.0 - on / off
			print("lean vs lane: %+.1f%% with the scrub off, %+.1f%% with it on; the scrub itself costs %.1f%% of the speed" % [
				(1.0 - off / lane) * 100.0, (1.0 - on / lane) * 100.0, cost * 100.0])
			var ok: bool = _frames[1] > 60 and _frames[2] > 60 and cost >= SCRUB
			print("rail scrub %s" % ("WORKS" if ok else "NOT shown (no lean, or too little cost)"))
			quit(0 if ok else 1)
			return false
		_begin(_phase + 1)
	return false


func _label(phase: int) -> String:
	return ["lane, no rail", "on the rail, scrub off", "on the rail, scrub on "][phase]


func _begin(phase: int) -> void:
	_phase = phase
	_t = 0.0
	_contacts = 0
	_touched = false
	CarBody.rail_scrub = phase == 2
	var session: DriveSession = _scene.session
	var track: TrackData = _scene.track
	var pose: Dictionary = track.pose_at(START)
	_index = track.index_at(START)
	session.car.place(pose["position"], pose["heading"])
	session.car.input_source = _scripted


func _scripted() -> VehicleTypes.DriverInput:
	var car: CarBody = _scene.session.car
	var track: TrackData = _scene.track
	var throttle := 1.0 if _t < DRIVE_SECONDS else 0.0
	var steer := 0.0
	if _phase == 0:
		steer = clampf(-track.lateral_offset(car.global_position, _index) * 0.05, -0.1, 0.1)
	elif _t > LEAN_FROM:
		steer = LEAN_STEER if _touched else APPROACH_STEER
	return VehicleTypes.DriverInput.make(throttle, 0.0, steer, 0.0, "keyboard")
