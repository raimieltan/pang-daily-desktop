class_name RoadChallenge
extends Node
## Rivals on the road in free drive (docs/GAME_DESIGN.md "Rivals can be challenged by flashing
## headlights on the road"): one rival at a time cruises down Pass 1 ahead of the player. Close up
## behind it and flash the headlights (L / pad Y): it flashes back and an SP battle starts right
## there, already rolling. The rivals take turns; a new one shows up once the last is out of reach.

## Off for tools that drive free drive themselves (trailer captures, screenshots).
static var allowed := true

## Where the next cruiser appears ahead of the player (m), and when one is out of reach.
const SPAWN_AHEAD := 140.0
const LOST_AHEAD := 350.0
const LOST_BEHIND := 60.0
## Seconds before the next rival shows up.
const RESPAWN_SECONDS := 6.0
## A challenge is open with the rival this far ahead (m) and enough road left to battle on.
const CHALLENGE_NEAR := 4.0
const CHALLENGE_FAR := 35.0
const CHALLENGE_ROAD_LEFT := 300.0
## Cruising pace as a share of the rival's skill: CRUISE close by, easing to CRUISE_FAR when it is
## CRUISE_FAR_M ahead, so the player can always close up.
const CRUISE := 0.72
const CRUISE_FAR := 0.3
const CRUISE_FAR_M := 120.0
## The cruiser keeps to the right-hand lane (PH roads drive on the right).
const CRUISE_LANE := 1.7

var track: TrackData
var session: DriveSession
var vs_battle: VsBattle
var time_attack: TimeAttack
## Set by the menu when the player starts free drive; any race or the title turns it off.
var enabled := false

var _car: CarBody
var _driver: AiDriver
var _rival := -1
var _next := 0
var _wait := 0.0
var _index_hint := 0
var _prompt: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.add_to_group(&"play_hud")
	add_child(layer)
	_prompt = MangaType.label("", 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.position.y -= 150
	_prompt.visible = false
	layer.add_child(_prompt)


func _free_driving() -> bool:
	return allowed and enabled and not time_attack.active and not vs_battle.active and not session.replay.playing


func _physics_process(delta: float) -> void:
	if not _free_driving():
		_despawn()
		_prompt.visible = false
		return
	_index_hint = track.nearest_index(session.car.global_position, _index_hint)
	var me := _index_hint * track.spacing
	if _car == null:
		_wait -= delta
		if _wait <= 0.0 and me + SPAWN_AHEAD < track.finish_distance - CHALLENGE_ROAD_LEFT:
			_spawn(me + SPAWN_AHEAD)
		_prompt.visible = false
		return
	var ahead := _driver.distance - me
	var spec: Dictionary = VsBattle.RIVALS[_rival]
	_driver.skill = spec["skill"] * lerpf(CRUISE, CRUISE_FAR, clampf((ahead - CHALLENGE_FAR) / (CRUISE_FAR_M - CHALLENGE_FAR), 0.0, 1.0))
	if ahead > LOST_AHEAD or ahead < -LOST_BEHIND or _driver.distance >= track.finish_distance:
		_despawn()
		return
	var open := can_challenge()
	_prompt.visible = open
	if open:
		_prompt.text = "FLASH  [L]  ·  CHALLENGE %s" % VsBattle.RIVALS[_rival]["name"]


## The player is close behind the cruiser with road left to battle on.
func can_challenge() -> bool:
	if _car == null or not _free_driving():
		return false
	var ahead := _driver.distance - _index_hint * track.spacing
	return ahead > CHALLENGE_NEAR and ahead < CHALLENGE_FAR \
		and _driver.distance < track.finish_distance - CHALLENGE_ROAD_LEFT


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flash_lights") and not get_tree().paused:
		flash()


## The player flashes the headlights; if a challenge is open, the rival answers and it is on.
func flash() -> void:
	if session.visual:
		session.visual.flash()
	if not can_challenge():
		return
	var visual := _car.get_children().filter(func(n): return n is CarVisual)
	if not visual.is_empty():
		(visual[0] as CarVisual).flash()
	var car := _car
	var driver := _driver
	_car = null
	_driver = null
	_prompt.visible = false
	_wait = RESPAWN_SECONDS
	_next = (_rival + 1) % VsBattle.RIVALS.size()
	vs_battle.challenge(_rival, car, driver)


func cruiser() -> CarBody:
	return _car


func _spawn(distance: float) -> void:
	_rival = _next
	var spec: Dictionary = VsBattle.RIVALS[_rival]
	var made := vs_battle.make_rival(spec, CRUISE_LANE, track.pose_at(distance, CRUISE_LANE))
	_car = made[0]
	_driver = made[1]
	_driver.skill = spec["skill"] * CRUISE
	_driver.racing = true
	_driver.others = [session.car, _car]


func _despawn() -> void:
	if _car == null:
		return
	_car.input_source = func() -> VehicleTypes.DriverInput: return VehicleTypes.DriverInput.new()
	_car.get_parent().remove_child(_car)
	_car.queue_free()
	_car = null
	_driver = null
	_wait = RESPAWN_SECONDS
	_next = (_rival + 1) % VsBattle.RIVALS.size()
