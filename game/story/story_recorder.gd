class_name StoryRecorder
extends Node
## Jolo's camera and the car's data logger: samples a car at GhostLine.HZ while `recording`
## (pose, speed, steer, pedals, distance along the road) into GhostLine-format frames.

var car: CarBody
var track: TrackData
var recording := false
var frames := PackedFloat32Array()
var _clock := 0.0
var _index := 0


func begin() -> void:
	frames = PackedFloat32Array()
	_clock = 0.0
	_index = track.nearest_index(car.global_position) if track else 0
	recording = true
	_sample()


func stop() -> PackedFloat32Array:
	recording = false
	return frames


func _physics_process(delta: float) -> void:
	if not recording or car == null:
		return
	_clock += delta
	while _clock >= 1.0 / GhostLine.HZ:
		_clock -= 1.0 / GhostLine.HZ
		_sample()


func _sample() -> void:
	var p := car.global_position
	var q := car.global_basis.get_rotation_quaternion()
	var input := car.last_input
	var d := 0.0
	if track:
		_index = track.nearest_index(p, _index)
		d = _index * track.spacing
	frames.append_array([p.x, p.y, p.z, q.x, q.y, q.z, q.w, car.linear_velocity.length(),
		input.steer, input.throttle, input.brake, d])
