extends RefCounted
## Leaning on a guardrail costs speed: the body stays frictionless in the physics engine (a brush
## must not snag), and the car applies its own scrub along the rail from how hard it is pushed
## into it and how fast it slides.

var errors: Array[String] = []


func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)


func test_rail_scrub_follows_push_and_slide() -> void:
	var dt := 1.0 / 120.0
	var mass := 1100.0
	_check(CarBody.rail_drag(40.0, 0.2, dt, mass) == 0.0, "no scrub when the car is not sliding along the rail")
	var light := CarBody.rail_drag(20.0, 15.0, dt, mass)
	var hard := CarBody.rail_drag(80.0, 15.0, dt, mass)
	_check(light > 0.0 and hard > light, "pushing harder into the rail scrubs harder")
	_check(absf(light - CarBody.RAIL_MU * 20.0 / dt) < 1e-6, "scrub is RAIL_MU times the push (impulse over the step)")
	var huge := CarBody.rail_drag(100000.0, 15.0, dt, mass)
	_check(absf(huge - CarBody.RAIL_DRAG_MAX_G * 9.81 * mass) < 1e-6, "a hard hit is capped at RAIL_DRAG_MAX_G")
	_check(CarBody.rail_drag(20.0, 15.0, dt, mass) == CarBody.rail_drag(20.0, 40.0, dt, mass), "sliding friction does not grow with speed")
