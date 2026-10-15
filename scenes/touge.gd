extends Node3D
## Touge run on Pass 1: the generated map, golden-hour light and a player car at the start line.
## Reset (R) puts the car back on the road centre at the nearest point, facing downhill.

const MAP := preload("res://maps/touge_01/touge_01.scn")
const TRACK := preload("res://maps/touge_01/track.res")

var session: DriveSession
var car: CarBody:
	get: return session.car if session else null
var track: TrackData = TRACK
var _progress_index := 0


func _ready() -> void:
	_build_environment()
	add_child(MAP.instantiate())
	var spawn := track.pose_at(track.start_distance - 12.0, 0.0)
	session = DriveSession.new(spawn["position"], spawn["heading"])
	session.reset_pose = _reset_pose
	add_child(session)


func _physics_process(_delta: float) -> void:
	if session and session.car:
		_progress_index = track.nearest_index(session.car.global_position, _progress_index)


func _reset_pose(car: CarBody) -> Dictionary:
	var i := track.nearest_index(car.global_position, _progress_index)
	return track.pose_at(i * track.spacing)


func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.33, 0.55)
	sky_material.sky_horizon_color = Color(0.93, 0.68, 0.45)
	sky_material.ground_horizon_color = Color(0.45, 0.4, 0.35)
	sky_material.ground_bottom_color = Color(0.12, 0.13, 0.12)
	sky_material.sun_angle_max = 20.0
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.62, 0.5)
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.3
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 125, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
