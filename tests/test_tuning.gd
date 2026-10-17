extends RefCounted
## Tuning (docs/GAME_DESIGN.md "Tuning system"): nine sliders, each a step count around stock,
## mapped onto the car's physical config; three saved setups per car.

var errors: Array[String] = []


func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func _stock() -> Dictionary:
	return HandlingPresets.physical_config(HandlingPresets.resolve("fwd_sport_hatch"))


func test_nine_sliders_with_hints() -> void:
	_check(CarSetup.SLIDERS.size() == 9, "nine sliders (got %d)" % CarSetup.SLIDERS.size())
	var keys := {}
	for s in CarSetup.SLIDERS:
		_check(s.has("key") and s.has("label") and s.has("hint") and s["hint"] != "", "%s: key, label and a plain-words hint" % s.get("key"))
		keys[s["key"]] = true
	_check(keys.size() == 9, "slider keys are distinct")
	for key in ["pressure", "height", "spring", "damping", "camber", "toe", "bias", "final", "lsd"]:
		_check(keys.has(key), "slider %s exists" % key)


func test_stock_setup_changes_nothing() -> void:
	var base := _stock()
	var tuned := CarSetup.apply(base, CarSetup.stock())
	_check(tuned == base, "all sliders at 0 leave the config as it was")
	_check(CarSetup.apply(base, {}) == base, "missing values read as stock")


func test_sliders_move_the_right_parameters() -> void:
	var base := _stock()
	var m: Dictionary = base["mechanical"]
	var soft := CarSetup.apply(base, { "pressure": -3 })
	_check(soft["tires"]["frontGrip"] > base["tires"]["frontGrip"] and soft["tires"]["rearGrip"] > base["tires"]["rearGrip"],
		"lower pressure: more grip")
	_check(soft["tires"]["frontPeakSlipDeg"] > base["tires"]["frontPeakSlipDeg"], "lower pressure: lazier steering (peak further out)")
	var hard := CarSetup.apply(base, { "pressure": 3 })
	_check(hard["tires"]["frontGrip"] < base["tires"]["frontGrip"], "higher pressure: less grip")
	var low := CarSetup.apply(base, { "height": -2 })
	_check(low["mechanical"]["suspension"]["rideHeightOffsetM"] < m["suspension"]["rideHeightOffsetM"], "lower ride height")
	var stiff := CarSetup.apply(base, { "spring": 2, "damping": 1 })
	_check(stiff["mechanical"]["suspension"]["frontSpring"] > m["suspension"]["frontSpring"]
		and stiff["mechanical"]["suspension"]["rearSpring"] > m["suspension"]["rearSpring"], "stiffer springs, both axles")
	_check(stiff["mechanical"]["suspension"]["damping"] > m["suspension"]["damping"], "more damping")
	var geo := CarSetup.apply(base, { "camber": 2, "toe": -1 })
	_check(geo["mechanical"]["suspension"]["camberDeg"] < m["suspension"]["camberDeg"], "more camber is more negative")
	_check(geo["mechanical"]["suspension"]["toeDeg"] < m["suspension"]["toeDeg"], "toe-out is less toe-in")
	var rear := CarSetup.apply(base, { "bias": -2 })
	_check(absf(rear["brakes"]["frontBias"] - (base["brakes"]["frontBias"] - 0.06)) < 1e-6, "brake bias: 0.03 rearward a step")
	var short := CarSetup.apply(base, { "final": 2 })
	_check(short["mechanical"]["engine"]["finalDrive"] > m["engine"]["finalDrive"], "shorter final drive")
	var lsd := CarSetup.apply(base, { "lsd": 2 })
	_check(lsd["mechanical"]["differential"]["type"] == "lsd" and lsd["mechanical"]["differential"]["lock"] > 0.0,
		"lock on an open diff makes it an LSD (got %s)" % [lsd["mechanical"]["differential"]])
	_check(CarSetup.apply(base, { "lsd": 3 })["mechanical"]["differential"]["lock"] <= 1.0, "lock stays within 0..1")
	_check(CarSetup.apply(base, { "lsd": -3 })["mechanical"]["differential"]["lock"] >= 0.0, "...and never negative")
	_check(base == _stock(), "apply does not touch the config it was given")


func test_setups_are_saved_per_car_in_three_slots() -> void:
	var path := "user://test_setups.json"
	var before := CarSetup.path
	CarSetup.path = path
	CarSetup.data = {}
	CarSetup.set_value("eg_hatch", "pressure", -2)
	CarSetup.set_value("eg_hatch", "bias", 1)
	_check(CarSetup.values("eg_hatch")["pressure"] == -2, "a value set is a value read")
	_check(CarSetup.values("civic_fd").get("pressure", 0) == 0, "another car is stock")
	CarSetup.set_slot("eg_hatch", 2)
	_check(CarSetup.slot("eg_hatch") == 2 and CarSetup.values("eg_hatch").get("pressure", 0) == 0, "a fresh slot is stock")
	CarSetup.set_value("eg_hatch", "final", 3)
	CarSetup.set_slot("eg_hatch", 0)
	_check(CarSetup.values("eg_hatch")["pressure"] == -2 and CarSetup.values("eg_hatch").get("final", 0) == 0,
		"each slot keeps its own values")
	CarSetup.data = {}
	CarSetup.load_setups()
	_check(CarSetup.slot("eg_hatch") == 0 and CarSetup.values("eg_hatch")["bias"] == 1, "values survive a reload")
	CarSetup.set_slot("eg_hatch", 2)
	_check(CarSetup.values("eg_hatch")["final"] == 3, "...in every slot")
	CarSetup.set_value("eg_hatch", "final", 9)
	_check(CarSetup.values("eg_hatch")["final"] == CarSetup.HI, "values are clamped to the slider range")
	CarSetup.reset("eg_hatch")
	_check(CarSetup.values("eg_hatch").is_empty() or CarSetup.values("eg_hatch") == CarSetup.stock(), "reset is stock")
	CarSetup.data = {}
	CarSetup.path = before
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
