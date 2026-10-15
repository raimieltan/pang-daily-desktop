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
var vs_battle: VsBattle
var intro: RaceIntro
var music: MusicPlayer
var menu: GameMenu
var _progress_index := 0


func _ready() -> void:
	_build_environment()
	add_child(MAP.instantiate())
	var spawn := track.pose_at(track.start_distance - 12.0, 0.0)
	session = DriveSession.new(spawn["position"], spawn["heading"])
	session.reset_pose = _reset_pose
	session.track = track
	add_child(session)
	session.minimap.track = track
	music = MusicPlayer.new()
	add_child(music)
	intro = RaceIntro.new()
	intro.hud_nodes = [session.gauges, session.day_night]
	add_child(intro)
	time_attack = TimeAttack.new()
	time_attack.track = track
	time_attack.session = session
	time_attack.intro = intro
	time_attack.music = music
	add_child(time_attack)
	vs_battle = VsBattle.new()
	vs_battle.track = track
	vs_battle.session = session
	vs_battle.intro = intro
	vs_battle.music = music
	add_child(vs_battle)
	session.replay.frozen_nodes.assign([time_attack, vs_battle])
	menu = GameMenu.new()
	menu.session = session
	menu.time_attack = time_attack
	menu.vs_battle = vs_battle
	menu.music = music
	add_child(menu)


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
