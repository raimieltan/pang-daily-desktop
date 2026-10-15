extends Node3D
## Touge run on Pass 1: the generated map, golden-hour light and a player car at the start line.
## Reset (R) puts the car back on the road centre at the nearest point, facing downhill.

const MAP := preload("res://maps/touge_01/touge_01.scn")
const TRACK := preload("res://maps/touge_01/track.res")

var session: DriveSession
var car: CarBody:
	get: return session.car if session else null
var track: TrackData = TRACK
var time_attack: TimeAttack
var _progress_index := 0


func _ready() -> void:
	_build_environment()
	add_child(MAP.instantiate())
	var spawn := track.pose_at(track.start_distance - 12.0, 0.0)
	session = DriveSession.new(spawn["position"], spawn["heading"])
	session.reset_pose = _reset_pose
	add_child(session)
	time_attack = TimeAttack.new()
	time_attack.track = track
	time_attack.session = session
	add_child(time_attack)


func _physics_process(_delta: float) -> void:
	if session and session.car:
		_progress_index = track.nearest_index(session.car.global_position, _progress_index)


func _reset_pose(car: CarBody) -> Dictionary:
	var i := track.nearest_index(car.global_position, _progress_index)
	return track.pose_at(i * track.spacing)


func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = MangaArt.environment()
	add_child(world_env)
	add_child(MangaArt.sun())
