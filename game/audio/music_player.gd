class_name MusicPlayer
extends Node
## Background music: one looping track at a time on the "Music" bus, crossfaded between tracks.
## Ids: &"race" (VS battles, time attack), &"race_alt", &"menu" (title menu, free drive).
## Missing ids fall back to the race track. duck() lowers the music for cutscenes and pause.

const BUS := &"Music"
const BUS_DB := -8.0
const DUCK_DB := -8.0
const SILENT_DB := -60.0
const CROSSFADE := 1.5

const TRACKS := {
	&"race": "res://assets/audio/music/race_hot_roadway.ogg",
	&"race_alt": "res://assets/audio/music/race_technomania101.ogg",
	&"menu": "res://assets/audio/music/menu_midnight_drive.ogg",
}

var current: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _ducked := false
var _base_db := BUS_DB
var _tweens: Array[Tween] = [null, null]


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_ensure_bus()
	_base_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS))
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)


## Crossfade to the track with this id. Does nothing if it is already playing.
func play_track(id: StringName) -> void:
	var path: String = TRACKS.get(id, TRACKS[&"race"])
	if not ResourceLoader.exists(path):
		path = TRACKS[&"race"]
	if id == current and _players[_active].playing:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("MusicPlayer: cannot load %s" % path)
		return
	if "loop" in stream:
		stream.loop = true
	current = id
	_fade(_active, SILENT_DB, CROSSFADE, true)
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_db = SILENT_DB
	p.play()
	_fade(_active, 0.0, CROSSFADE, false)


## Fade the current track out and stop it.
func stop_music(fade := 1.0) -> void:
	current = &""
	_fade(_active, SILENT_DB, fade, true)


## Drop the whole Music bus by about 8 dB (cutscenes, pause) or restore it.
func duck(on: bool) -> void:
	if on == _ducked:
		return
	_ducked = on
	var idx := AudioServer.get_bus_index(BUS)
	var from := AudioServer.get_bus_volume_db(idx)
	var to := _base_db + (DUCK_DB if on else 0.0)
	var t := create_tween()
	t.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(idx, db), from, to, 0.4)


func _fade(i: int, to_db: float, time: float, stop_after: bool) -> void:
	if _tweens[i] and _tweens[i].is_valid():
		_tweens[i].kill()
	var p := _players[i]
	if not p.playing:
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", to_db, maxf(time, 0.01))
	if stop_after:
		t.tween_callback(p.stop)
	_tweens[i] = t


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(idx, BUS_DB)
