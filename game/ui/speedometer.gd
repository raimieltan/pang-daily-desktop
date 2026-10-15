class_name Speedometer
extends Control
## Manga speedometer (docs/ART_DIRECTION.md §7): a hand-inked gauge on a paper disc with a hard
## ink drop shadow, a red-tipped needle, an inner tachometer arc in tone segments with a red
## redline, outlined display numerals and the gear in a speech burst. Sits bottom-right.

const PAPER := MangaType.PAPER
const INK := MangaType.INK
const RED := MangaType.RED

const MAX_KMH := 260.0
const MAX_RPM := 8000.0
const REDLINE_RPM := 7000.0
const SWEEP_START := PI * 5.0 / 6.0
const SWEEP := PI * 4.0 / 3.0
const SHADOW := Vector2(8, 8)
const RIM := 9.0
const FAST_KMH := 150.0

var car: CarBody
## Debug override for previews: { speed, rpm, gear }. Non-empty replaces the car readout.
var preview := {}

var _speed := 0.0
var _rpm := 0.0
var _gear := "N"
var _shown_speed := 0.0
var _shown_rpm := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	custom_minimum_size = Vector2(260, 260)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not _read():
		return
	var k := 1.0 - exp(-14.0 * delta)
	_shown_speed = lerpf(_shown_speed, _speed, k)
	_shown_rpm = lerpf(_shown_rpm, _rpm, k)
	queue_redraw()


func _read() -> bool:
	if not preview.is_empty():
		_speed = absf(float(preview.get("speed", 0.0)))
		_rpm = float(preview.get("rpm", 0.0))
		_gear = str(preview.get("gear", "N"))
		return true
	if car == null or car.model == null:
		return false
	var mech := car.model.mechanics
	var s := car.model.state
	_speed = absf(car.speed_kmh())
	_rpm = mech.engine_rpm
	_gear = "R" if s.reversing else ("N" if s.neutral else str(mech.gear))
	return true


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 - SHADOW.x * 0.5 - 2.0
	var center := Vector2(radius + 2.0, radius + 2.0) + _shake()
	_draw_speed_lines(center, radius)
	draw_circle(center + SHADOW, radius, INK)
	draw_circle(center, radius, PAPER)
	_draw_rpm(center, radius * 0.5)
	_draw_ticks(center, radius - RIM)
	_draw_digits(center + Vector2(0, radius * 0.5))
	_draw_needle(center, radius - RIM - 6.0)
	draw_arc(center, radius - RIM * 0.5, 0.0, TAU, 96, INK, RIM, true)
	_draw_gear(center + Vector2(radius, radius) * 0.74)


func _fast() -> float:
	return clampf((_shown_speed - FAST_KMH) / (MAX_KMH - FAST_KMH), 0.0, 1.0)


func _shake() -> Vector2:
	var f := _fast()
	if f <= 0.0:
		return Vector2.ZERO
	return Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 1.6 * f


## Horizontal ink streaks trailing off the left of the disc, like a panel's motion lines.
func _draw_speed_lines(center: Vector2, radius: float) -> void:
	var f := _fast()
	if f <= 0.0:
		return
	for i in int(3 + 5 * f):
		var y := _rng.randf_range(-0.8, 0.8) * radius
		var edge := center.x - sqrt(maxf(0.0, radius * radius - y * y)) - 6.0
		var length := _rng.randf_range(18.0, 54.0) * (0.5 + f)
		var half := _rng.randf_range(1.0, 2.5)
		var root := Vector2(edge, center.y + y)
		draw_colored_polygon(PackedVector2Array([root + Vector2(0, -half), root + Vector2(0, half), root - Vector2(length, 0)]), INK)


func _angle(t: float) -> float:
	return SWEEP_START + SWEEP * clampf(t, 0.0, 1.0)


func _draw_ticks(center: Vector2, radius: float) -> void:
	var font := MangaType.caption()
	for kmh in range(0, int(MAX_KMH) + 1, 10):
		var dir := Vector2.from_angle(_angle(kmh / MAX_KMH))
		var major := kmh % 20 == 0
		var inner := radius - (16.0 if major else 8.0)
		draw_line(center + dir * inner, center + dir * radius, INK, 4.0 if major else 2.0)
		if major:
			_draw_centered(font, str(kmh), center + dir * (radius - 29.0), 17, INK)


## Inner tachometer: an inked arc of short segments, filled to the current rpm, red past redline.
func _draw_rpm(center: Vector2, radius: float) -> void:
	var steps := 32
	var step_rpm := MAX_RPM / steps
	var span := SWEEP / steps
	for i in steps:
		var a := SWEEP_START + span * i
		var lit := (i + 0.5) * step_rpm <= _shown_rpm
		var red := i * step_rpm >= REDLINE_RPM
		var colour := RED if red and lit else INK
		if lit:
			draw_arc(center, radius, a + span * 0.12, a + span * 0.88, 4, colour, 12.0)
		else:
			draw_arc(center, radius + 4.0, a + span * 0.12, a + span * 0.88, 4, colour, 3.0)
	var red_from := _angle(REDLINE_RPM / MAX_RPM)
	draw_arc(center, radius - 9.0, SWEEP_START, red_from, 48, INK, 2.0)
	draw_arc(center, radius - 10.0, red_from, _angle(1.0), 12, RED, 5.0)
	_draw_centered(MangaType.caption(), "RPM", center + Vector2(0, -radius * 0.42), 15, INK)


func _draw_digits(at: Vector2) -> void:
	var font := MangaType.display()
	_draw_outlined(font, "%d" % roundi(_shown_speed), at, 42)
	_draw_centered(MangaType.caption(), "KM/H", at + Vector2(0, 30), 16, INK)


func _draw_needle(center: Vector2, length: float) -> void:
	var dir := Vector2.from_angle(_angle(_shown_speed / MAX_KMH))
	var side := dir.orthogonal()
	var tail := center - dir * 18.0
	var tip := center + dir * length
	var neck := center + dir * length * 0.74
	draw_colored_polygon(PackedVector2Array([tail + side * 4.0, neck + side * 4.0, neck - side * 4.0, tail - side * 4.0]), INK)
	var red := PackedVector2Array([neck + side * 4.5, tip, neck - side * 4.5])
	draw_colored_polygon(red, RED)
	draw_polyline(PackedVector2Array([neck + side * 4.5, tip, neck - side * 4.5, neck + side * 4.5]), INK, 2.0, true)
	draw_circle(center, 11.0, INK)
	draw_circle(center, 4.0, PAPER)


## Gear letter in a jagged speech burst with its own hard shadow.
func _draw_gear(at: Vector2) -> void:
	var burst := _burst(at, 34.0, 25.0, 12)
	var shadow := burst.duplicate()
	for i in shadow.size():
		shadow[i] += SHADOW * 0.6
	draw_colored_polygon(shadow, INK)
	draw_colored_polygon(burst, RED if _gear == "R" else PAPER)
	burst.append(burst[0])
	draw_polyline(burst, INK, 4.0, true)
	_draw_centered(MangaType.display(), _gear, at, 30, INK)


func _burst(at: Vector2, outer: float, inner: float, points: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		if i % 4 == 0:
			r *= 1.12
		poly.append(at + Vector2.from_angle(TAU * i / (points * 2) - PI * 0.5) * r)
	return poly


func _draw_centered(font: Font, text: String, at: Vector2, font_size: int, colour: Color) -> void:
	draw_string(font, _baseline(font, text, at, font_size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _draw_outlined(font: Font, text: String, at: Vector2, font_size: int) -> void:
	var base := _baseline(font, text, at, font_size)
	draw_string_outline(font, base + SHADOW * 0.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 10, INK)
	draw_string(font, base + SHADOW * 0.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 10, INK)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, PAPER)


func _baseline(font: Font, text: String, at: Vector2, font_size: int) -> Vector2:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	return at + Vector2(-w * 0.5, (ascent - descent) * 0.5)
