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
var road_challenge: RoadChallenge
var intro: RaceIntro
var music: MusicPlayer
var menu: GameMenu
var _progress_index := 0
var _kyo_hint: Label


func _ready() -> void:
	_build_environment()
	add_child(MAP.instantiate())
	var spawn := track.pose_at(track.start_distance - 12.0, 0.0)
	session = DriveSession.new(spawn["position"], spawn["heading"])
	if StoryMode.active:
		session.car_spec = CarRoster.get_car(StoryMode.CAR_ID)
		session.paint = StoryMode.CAR_PAINT
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
	road_challenge = RoadChallenge.new()
	road_challenge.track = track
	road_challenge.session = session
	road_challenge.vs_battle = vs_battle
	road_challenge.time_attack = time_attack
	add_child(road_challenge)
	var life := RoadsideLife.new()
	life.name = "RoadsideLife"
	life.track = track
	life.racing = func() -> bool: return time_attack.active or vs_battle.active
	add_child(life)
	session.replay.frozen_nodes.assign([time_attack, vs_battle, road_challenge, life])
	var ambience := Ambience.new()
	ambience.name = "Ambience"
	ambience.listener = session.camera
	add_child(ambience)
	menu = GameMenu.new()
	menu.session = session
	menu.time_attack = time_attack
	menu.vs_battle = vs_battle
	menu.road_challenge = road_challenge
	menu.music = music
	# Arriving from the barangay: straight onto the road, no title.
	var from_hub := HubChallenge.rival >= 0 or HubChallenge.free_drive
	var skip := GameMenu.skip_title
	GameMenu.skip_title = skip or from_hub or StoryMode.active
	add_child(menu)
	GameMenu.skip_title = skip
	if StoryMode.active:
		_start_story.call_deferred()
	elif from_hub:
		_start_from_hub.call_deferred()


## Story mode (StoryMode): the director plays its beats on this road.
func _start_story() -> void:
	time_attack.free_drive()
	music.stop_music()
	var director := StoryDirector.new()
	director.name = "StoryDirector"
	director.stage = "pass"
	director.session = session
	director.time_attack = time_attack
	director.vs_battle = vs_battle
	director.music = music
	add_child(director)


## A challenge made in the barangay: the SP battle against that rival (or free drive from the
## main road's exit), and E takes you back to Kyo once it is over.
func _start_from_hub() -> void:
	if HubChallenge.car_id != "":
		session.set_car(HubChallenge.car_id)
	_kyo_hint = MangaType.label("E   BACK TO KYO", 30)
	_kyo_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_kyo_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_kyo_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_kyo_hint.position.y = -60
	var layer := CanvasLayer.new()
	layer.layer = 12
	layer.add_child(_kyo_hint)
	add_child(layer)
	time_attack.free_drive()
	if HubChallenge.rival >= 0:
		_kyo_hint.visible = false
		vs_battle.sp_rival = HubChallenge.rival
		vs_battle.finished.connect(func(_place: int): _kyo_hint.visible = true, CONNECT_ONE_SHOT)
		vs_battle.start()
	else:
		music.stop_music()
	HubChallenge.rival = -1
	HubChallenge.free_drive = false


func _unhandled_input(event: InputEvent) -> void:
	if _kyo_hint and _kyo_hint.visible and InputMap.has_action("interact") and event.is_action_pressed("interact"):
		HubChallenge.back_to_hub(get_tree())


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
