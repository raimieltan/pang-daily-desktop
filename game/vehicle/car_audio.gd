class_name CarAudio
extends Node
## Player-car sound, all driven by the sim. Sources and licences: assets/audio/CREDITS.md
## (engine: qubodup, CC-BY 3.0; squeal: audible-edge/qubodup, CC-BY 3.0; impacts: Kenney, CC0).
## - Engine: one I4 loop on two players, pitched by rpm. The on-load layer follows throttle; the
##   off-load layer runs through a low-pass bus, so lifting sounds muffled, not just quieter.
## - Tires: a squeal loop whose volume follows how far past their peak the tires are working.
## - Contacts: metal hits scaled by impulse, rapid light ticks while scraping a rail.
## Non-positional players: the camera is always on the player car, and that is cheaper.

const ENGINE := preload("res://assets/audio/engine/i4_loop.wav")
const SQUEAL := preload("res://assets/audio/tire/squeal_loop.wav")
const HITS := [
	preload("res://assets/audio/impact/impactMetal_heavy_000.ogg"),
	preload("res://assets/audio/impact/impactMetal_heavy_002.ogg"),
	preload("res://assets/audio/impact/impactMetal_heavy_004.ogg"),
	preload("res://assets/audio/impact/impactPlate_medium_000.ogg"),
	preload("res://assets/audio/impact/impactPlate_medium_002.ogg"),
]
const TICKS := [
	preload("res://assets/audio/impact/impactMetal_light_000.ogg"),
	preload("res://assets/audio/impact/impactMetal_light_001.ogg"),
	preload("res://assets/audio/impact/impactMetal_light_003.ogg"),
]
## Engine speed the loop was recorded at (pitch 1.0). By ear: a steady mid-range rev.
const LOOP_RPM := 3300.0

var car: CarBody
var _engine_on := AudioStreamPlayer.new()
var _engine_off := AudioStreamPlayer.new()
var _squeal := AudioStreamPlayer.new()
var _hits: Array[AudioStreamPlayer] = []
var _hit_cooldown := 0.0
var _scrape_until := 0.0
var _next_tick := 0.0
var _clock := 0.0
var _load := 0.0
var _squeal_level := 0.0


static func ensure_buses() -> void:
	if AudioServer.get_bus_index("Engine") >= 0:
		return
	for bus in ["Engine", "EngineOff", "Tires", "Fx"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
	var lowpass := AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 1100.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("EngineOff"), lowpass)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), -4.0)


static func _looped(stream: AudioStreamWAV) -> AudioStreamWAV:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


func _ready() -> void:
	ensure_buses()
	for p in [[_engine_on, ENGINE, "Engine"], [_engine_off, ENGINE, "EngineOff"], [_squeal, SQUEAL, "Tires"]]:
		var player: AudioStreamPlayer = p[0]
		player.stream = _looped(p[1])
		player.bus = p[2]
		player.volume_db = -80.0
		add_child(player)
		player.play()
	# Offset the second engine layer so the two copies never phase into one.
	_engine_off.seek(1.7)
	for i in 3:
		var hit := AudioStreamPlayer.new()
		hit.bus = "Fx"
		add_child(hit)
		_hits.append(hit)
	if car:
		car.wall_contact.connect(_on_wall_contact)


func _process(delta: float) -> void:
	if car == null or car.model == null:
		return
	_clock += delta
	var mech := car.model.mechanics
	var s := car.model.state
	var rpm := mech.engine_rpm
	var pitch := clampf(rpm / LOOP_RPM, 0.35, 2.3)
	_engine_on.pitch_scale = pitch
	_engine_off.pitch_scale = pitch * 0.98
	_load = move_toward(_load, s.throttle, delta * 6.0)
	var rev := clampf(rpm / 6500.0, 0.0, 1.0)
	_engine_on.volume_db = linear_to_db(lerpf(0.05, 1.0, _load) * lerpf(0.55, 1.0, rev))
	_engine_off.volume_db = linear_to_db(lerpf(0.55, 0.08, _load) * lerpf(0.6, 0.9, rev))
	# Squeal: how far past the peak (demand 1 = at the peak) the loudest grounded tire is working.
	var speed := car.linear_velocity.length()
	var level := 0.0
	for w in mech.wheels:
		if w.is_grounded:
			level = maxf(level, smoothstep(1.05, 2.2, w.demand))
	level *= smoothstep(3.0, 8.0, speed)
	_squeal_level = move_toward(_squeal_level, level, delta * 5.0)
	_squeal.volume_db = linear_to_db(maxf(_squeal_level * 0.75, 0.0001))
	_squeal.pitch_scale = 0.9 + 0.25 * _squeal_level + speed * 0.002
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if _clock < _scrape_until and _clock >= _next_tick:
		_play(TICKS.pick_random(), -14.0, randf_range(0.9, 1.25))
		_next_tick = _clock + randf_range(0.05, 0.11)


func _on_wall_contact(_point: Vector3, _normal: Vector3, dv: float, slide: float) -> void:
	if slide > 4.0:
		_scrape_until = _clock + 0.12
	if dv > 2.5 and _hit_cooldown == 0.0:
		var loud := clampf((dv - 2.5) / 6.0, 0.0, 1.0)
		_play(HITS.pick_random(), lerpf(-12.0, 0.0, loud), randf_range(0.85, 1.05))
		_hit_cooldown = 0.18


func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	for p in _hits:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
