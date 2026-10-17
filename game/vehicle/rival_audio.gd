class_name RivalAudio
extends Node
## A rival car's engine: the same I4 loop as the player's (CarAudio), on one positional player,
## pitched by its rpm, louder on the throttle and at revs, trimmed under the player's engine and
## fading with distance. Tires and impacts stay the player's own.

## Under the player's engine, in dB, at full load.
const TRIM_DB := -7.0
const MAX_DISTANCE := 140.0

var car: CarBody
var _player := AudioStreamPlayer3D.new()
var _load := 0.0


static func levels(rpm: float, load: float) -> Dictionary:
	var rev := clampf(rpm / 6500.0, 0.0, 1.0)
	var linear := lerpf(0.08, 1.0, clampf(load, 0.0, 1.0)) * lerpf(0.5, 1.0, rev)
	return { "pitch": clampf(rpm / CarAudio.LOOP_RPM, 0.35, 2.3), "db": linear_to_db(linear) + TRIM_DB }


func _ready() -> void:
	CarAudio.ensure_buses()
	_player.stream = CarAudio._looped(CarAudio.ENGINE)
	_player.bus = "Engine"
	_player.max_distance = MAX_DISTANCE
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_player.unit_size = 12.0
	_player.volume_db = -80.0
	add_child(_player)
	_player.play()
	# Not in step with the player's loop.
	_player.seek(0.9)


func _process(delta: float) -> void:
	if car == null or car.model == null:
		return
	_load = move_toward(_load, car.model.state.throttle, delta * 6.0)
	var l := levels(car.model.mechanics.engine_rpm, _load)
	_player.pitch_scale = l["pitch"]
	_player.volume_db = l["db"]
