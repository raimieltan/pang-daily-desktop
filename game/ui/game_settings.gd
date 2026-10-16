class_name GameSettings
extends RefCounted
## Player settings, saved to user://settings.cfg: volumes in 0–10 steps, display, VS opponents.
## Volume steps scale each bus from the level the game set it up at, so the mix stays balanced.

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"master": 10, "music": 8, "engine": 10, "effects": 10,
	"fullscreen": false, "vsync": true, "opponents": 3,
}
## The buses each volume slider drives (Music is handled by MusicPlayer, which also ducks it).
const BUSES := { "master": ["Master"], "engine": ["Engine", "EngineOff"], "effects": ["Tires", "Fx", "Ambience"] }
const MAX_OPPONENTS := 5

static var _values := {}
static var _bus_base := {}


static func value(key: String) -> Variant:
	_load()
	return _values.get(key, DEFAULTS[key])


static func set_value(key: String, v: Variant) -> void:
	_load()
	_values[key] = v
	var cfg := ConfigFile.new()
	for k in _values:
		cfg.set_value("settings", k, _values[k])
	cfg.save(PATH)


static func volume_db(steps: int) -> float:
	return -80.0 if steps <= 0 else linear_to_db(steps / 10.0)


static func apply_audio() -> void:
	for key in BUSES:
		for bus in BUSES[key]:
			var i := AudioServer.get_bus_index(bus)
			if i < 0:
				continue
			if not _bus_base.has(bus):
				_bus_base[bus] = AudioServer.get_bus_volume_db(i)
			AudioServer.set_bus_volume_db(i, _bus_base[bus] + volume_db(value(key)))


static func apply_display() -> void:
	var full: bool = value("fullscreen")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value("vsync") else DisplayServer.VSYNC_DISABLED)


static func _load() -> void:
	if not _values.is_empty():
		return
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in DEFAULTS:
			_values[k] = cfg.get_value("settings", k, DEFAULTS[k])
