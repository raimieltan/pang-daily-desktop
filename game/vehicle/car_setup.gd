class_name CarSetup
extends RefCounted
## Tuning (docs/GAME_DESIGN.md "Tuning system"): nine sliders, each a step count LO..HI around
## stock (0), that the player can feel on the next run, with Ruel's plain-words hint. A setup is
## { slider key: steps }; `apply` lays it over a car's physical config. Three setups a car, saved
## to user://setups.json. Tuning is free; the parts that would gate a slider are not built yet,
## so every slider is open.

const LO := -3
const HI := 3
## Per step: tire grip and where the lateral peak sits (pressure), ride height (m), spring and
## damping scale, camber and toe (deg), brake bias, final drive scale, LSD lock.
const PRESSURE_GRIP := 0.02
const PRESSURE_SLIP := 0.05
const HEIGHT_M := 0.012
const SPRING_SCALE := 0.08
const DAMPING_SCALE := 0.1
const CAMBER_DEG := 0.5
const TOE_DEG := 0.1
const BIAS := 0.03
const FINAL_SCALE := 0.04
const LSD_LOCK := 0.15

const SLIDERS := [
	{ "key": "pressure", "label": "TIRE PSI", "hint": "LOWER = MORE GRIP, LAZIER STEERING" },
	{ "key": "height", "label": "RIDE HEIGHT", "hint": "LOWER = LESS LEAN, SHARPER TURN-IN" },
	{ "key": "spring", "label": "SPRINGS", "hint": "STIFFER = LESS ROLL, QUICKER TO LOAD UP; SKIPS OVER PATCHES" },
	{ "key": "damping", "label": "DAMPING", "hint": "SOFTER SOAKS BUMPS; TOO STIFF = SKIPS OVER PATCHES" },
	{ "key": "camber", "label": "CAMBER", "hint": "MORE NEGATIVE = MORE CORNER GRIP, LESS BRAKING" },
	{ "key": "toe", "label": "TOE", "hint": "TOE-OUT = QUICKER TURN-IN, LESS STABLE ON THE STRAIGHT" },
	{ "key": "bias", "label": "BRAKE BIAS", "hint": "REARWARD = THE CAR TURNS MORE ON THE BRAKES, CAN SPIN" },
	{ "key": "final", "label": "FINAL DRIVE", "hint": "SHORTER = FASTER OUT OF HAIRPINS, LESS TOP SPEED" },
	{ "key": "lsd", "label": "LSD LOCK", "hint": "MORE LOCK = PULLS OUT OF CORNERS, PUSHES WIDE ON ENTRY" },
]
const SLOTS := 3

static var path := "user://setups.json"
## { car id: { "slot": int, "setups": [ { key: steps }, ... ] } }
static var data := {}
static var _loaded := false


static func stock() -> Dictionary:
	return {}


static func steps(values: Dictionary, key: String) -> int:
	return clampi(int(values.get(key, 0)), LO, HI)


## The config with the setup on it: `physical` is HandlingPresets.physical_config(...) (it has
## the "mechanical" block); the result is a deep copy, the input untouched.
static func apply(physical: Dictionary, values: Dictionary) -> Dictionary:
	var c := physical.duplicate(true)
	var m: Dictionary = c["mechanical"]
	var p := steps(values, "pressure")
	if p != 0:
		var tires: Dictionary = c["tires"]
		tires["frontGrip"] = float(tires["frontGrip"]) * (1.0 - PRESSURE_GRIP * p)
		tires["rearGrip"] = float(tires["rearGrip"]) * (1.0 - PRESSURE_GRIP * p)
		tires["frontPeakSlipDeg"] = float(tires["frontPeakSlipDeg"]) * (1.0 - PRESSURE_SLIP * p)
		tires["rearPeakSlipDeg"] = float(tires["rearPeakSlipDeg"]) * (1.0 - PRESSURE_SLIP * p)
	var sus: Dictionary = m["suspension"]
	var h := steps(values, "height")
	if h != 0:
		sus["rideHeightOffsetM"] = float(sus["rideHeightOffsetM"]) + HEIGHT_M * h
	var s := steps(values, "spring")
	if s != 0:
		sus["frontSpring"] = float(sus["frontSpring"]) * (1.0 + SPRING_SCALE * s)
		sus["rearSpring"] = float(sus["rearSpring"]) * (1.0 + SPRING_SCALE * s)
	var d := steps(values, "damping")
	if d != 0:
		sus["damping"] = float(sus["damping"]) * (1.0 + DAMPING_SCALE * d)
	var cam := steps(values, "camber")
	if cam != 0:
		sus["camberDeg"] = float(sus["camberDeg"]) - CAMBER_DEG * cam
	var toe := steps(values, "toe")
	if toe != 0:
		sus["toeDeg"] = float(sus["toeDeg"]) + TOE_DEG * toe
	var b := steps(values, "bias")
	if b != 0:
		c["brakes"]["frontBias"] = clampf(float(c["brakes"]["frontBias"]) + BIAS * b, 0.3, 0.9)
	var f := steps(values, "final")
	if f != 0:
		m["engine"]["finalDrive"] = float(m["engine"]["finalDrive"]) * (1.0 + FINAL_SCALE * f)
	var l := steps(values, "lsd")
	if l != 0:
		var diff: Dictionary = m["differential"]
		var lock := clampf(float(diff.get("lock", 0.0)) + LSD_LOCK * l, 0.0, 1.0)
		diff["lock"] = lock
		if diff.get("type", "open") == "open" and lock > 0.0:
			diff["type"] = "lsd"
	return c


# --- Saved setups -----------------------------------------------------------------------------


static func load_setups() -> void:
	_loaded = true
	data = {}
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		data = parsed


static func save_setups() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


static func _car(car_id: String) -> Dictionary:
	if not _loaded:
		load_setups()
	if not data.has(car_id):
		var setups := []
		for i in SLOTS:
			setups.append({})
		data[car_id] = { "slot": 0, "setups": setups }
	return data[car_id]


static func slot(car_id: String) -> int:
	return clampi(int(_car(car_id)["slot"]), 0, SLOTS - 1)


static func set_slot(car_id: String, i: int) -> void:
	_car(car_id)["slot"] = clampi(i, 0, SLOTS - 1)
	save_setups()


## The current slot's values, { key: steps }.
static func values(car_id: String) -> Dictionary:
	return _car(car_id)["setups"][slot(car_id)]


static func set_value(car_id: String, key: String, v: int) -> void:
	values(car_id)[key] = clampi(v, LO, HI)
	save_setups()


static func reset(car_id: String) -> void:
	_car(car_id)["setups"][slot(car_id)] = {}
	save_setups()


## The slot's letter for the menu.
static func slot_name(i: int) -> String:
	return "SETUP " + String.chr(65 + i)
