extends RefCounted
## Rival engine sound: pitch follows rpm like the player's loop, the level follows load and revs,
## and a rival sits a little under the player's engine so the player's own car stays on top.

var errors: Array[String] = []


func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func test_rival_engine_levels() -> void:
	var idle := RivalAudio.levels(900.0, 0.0)
	var mid := RivalAudio.levels(CarAudio.LOOP_RPM, 0.0)
	var full := RivalAudio.levels(6500.0, 1.0)
	_check(absf(float(mid["pitch"]) - 1.0) < 1e-6, "the loop plays at pitch 1 at the rpm it was recorded at")
	_check(float(idle["pitch"]) < float(mid["pitch"]) and float(full["pitch"]) > float(mid["pitch"]), "pitch rises with rpm")
	_check(float(RivalAudio.levels(20000.0, 1.0)["pitch"]) <= 2.3 and float(RivalAudio.levels(0.0, 0.0)["pitch"]) >= 0.35, "pitch is clamped")
	_check(float(full["db"]) > float(idle["db"]), "louder on the throttle at revs")
	_check(float(full["db"]) <= RivalAudio.TRIM_DB + 0.01, "never louder than the trim under the player's engine")
