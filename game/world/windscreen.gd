class_name Windscreen
extends CanvasLayer
## Rain on the glass in the hood view: drops land with the rain, swell, run down in trails and blow
## up the glass with speed; the wipers sweep them off (with their sound) whenever it is raining.
## Drawn in ink by day and paper by night, so the drops read on the page either way. Weather owns it
## and decides when the view is inside the car (`shown`); `residue` leaves drops on parked glass.

const WIPER := preload("res://assets/audio/story/wiper.wav")
const MAX_DROPS := 260
## Blade sweep: rest angle, top of the stroke (radians from +x, screen up) and a stroke's time (s).
const REST := 0.04
const TOP := 1.95
const STROKE := 0.55

var shown := false
## 0..1 how hard it is raining on the glass.
var rain := 0.0
## Drops already on the glass when nothing is falling (a parked car after the rain).
var residue := 0.0:
	set(v):
		residue = v
		_seed_residue()
## m/s, for drops blowing up the glass.
var speed := 0.0
var wipers := true

var _page: Control
var _drops: Array[Dictionary] = []
var _spawn := 0.0
var _blade := REST
var _phase := -1.0
var _pause := 0.0
var _audio: AudioStreamPlayer


func _ready() -> void:
	layer = 2
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.draw.connect(_draw_glass)
	add_child(_page)
	_audio = AudioStreamPlayer.new()
	_audio.stream = WIPER
	_audio.volume_db = -10.0
	_audio.bus = "Fx" if AudioServer.get_bus_index("Fx") >= 0 else "Master"
	add_child(_audio)


func _process(delta: float) -> void:
	visible = shown
	if not shown:
		return
	var size := _page.size
	# New drops: more in harder rain and at speed (the glass runs into the rain).
	_spawn += delta * rain * (55.0 + speed * 2.2)
	while _spawn >= 1.0 and _drops.size() < MAX_DROPS:
		_spawn -= 1.0
		_drops.append(_drop(Vector2(randf() * size.x, randf() * size.y * 0.92)))
	_spawn = fmod(_spawn, 1.0)
	# Airflow pushes drops up and out from the middle of the glass; slow, they sag and run down.
	var blow := clampf((speed - 8.0) / 20.0, 0.0, 1.0)
	for d in _drops:
		d["age"] += delta
		d["r"] = minf(d["r"] + delta * 0.6 * rain, 8.5)
		var pos: Vector2 = d["pos"]
		var run := 0.0
		if d["r"] > 5.0:
			run = (d["r"] - 5.0) * 28.0
		var v := Vector2((pos.x / size.x - 0.5) * 140.0 * blow, run - 260.0 * blow * (d["r"] / 6.0))
		if v.length() > 1.0 and d["trail"] == Vector2.INF:
			d["trail"] = pos
		d["pos"] = pos + v * delta
		var trail: Vector2 = d["trail"]
		if trail != Vector2.INF and trail.distance_to(d["pos"]) > 70.0:
			d["trail"] = d["pos"] + (trail - d["pos"]).normalized() * 70.0
	_drops = _drops.filter(func(d: Dictionary) -> bool:
		var p: Vector2 = d["pos"]
		return p.y > -20.0 and p.y < size.y + 20.0 and p.x > -20.0 and p.x < size.x + 20.0)
	_wipe(delta, size)
	_page.queue_redraw()


func _drop(pos: Vector2) -> Dictionary:
	return { "pos": pos, "r": randf_range(2.0, 4.4), "age": 0.0, "trail": Vector2.INF }


func _seed_residue() -> void:
	if _page == null:
		return
	var size := _page.size if _page.size.x > 0.0 else Vector2(1152, 648)
	_drops.clear()
	for i in int(residue * 160.0):
		var d := _drop(Vector2(randf() * size.x, randf() * size.y))
		d["r"] = randf_range(1.2, 5.0)
		_drops.append(d)


## Both blades sweep up and back; whatever they pass over is gone.
func _wipe(delta: float, size: Vector2) -> void:
	if not wipers or rain < 0.2:
		_blade = move_toward(_blade, REST, delta * 4.0)
		return
	if _phase < 0.0:
		_pause -= delta
		if _pause > 0.0:
			return
		_phase = 0.0
		_audio.play()
	var before := _blade
	_phase += delta / (STROKE * 2.0)
	var t := minf(_phase, 1.0)
	_blade = lerpf(REST, TOP, sin(t * PI))
	if _phase >= 1.0:
		_phase = -1.0
		_blade = REST
		# Lighter rain, longer between strokes.
		_pause = lerpf(1.6, 0.15, rain)
	var lo := minf(before, _blade)
	var hi := maxf(before, _blade)
	for pivot in _pivots(size):
		var reach := _reach(size)
		_drops = _drops.filter(func(d: Dictionary) -> bool:
			var to: Vector2 = d["pos"] - pivot
			var a := atan2(-to.y, to.x)
			return not (to.length() < reach and a >= lo - 0.05 and a <= hi + 0.05))


func _pivots(size: Vector2) -> Array[Vector2]:
	return [Vector2(size.x * 0.2, size.y + 18.0), Vector2(size.x * 0.6, size.y + 18.0)]


func _reach(size: Vector2) -> float:
	return size.y * 0.98


func _draw_glass() -> void:
	var size := _page.size
	var ink := MangaType.INK.lerp(MangaType.PAPER, MangaArt.night)
	var shine := MangaType.PAPER.lerp(MangaType.INK, MangaArt.night)
	for d in _drops:
		var p: Vector2 = d["pos"]
		var r: float = d["r"]
		var trail: Vector2 = d["trail"]
		if trail != Vector2.INF and trail.distance_to(p) > 2.0:
			_page.draw_line(trail, p, Color(ink, 0.35), maxf(1.0, r * 0.5))
		# A drop: a heavy lower rim (the lens of water) and a catchlight up-left.
		_page.draw_arc(p, r, 0.2, PI - 0.2, 10, Color(ink, 0.85), maxf(1.2, r * 0.38))
		_page.draw_arc(p, r, PI, TAU, 8, Color(ink, 0.35), 1.0)
		_page.draw_circle(p + Vector2(-r, -r) * 0.35, maxf(0.8, r * 0.28), Color(shine, 0.8))
	if rain >= 0.2 or _blade > REST + 0.01:
		for pivot in _pivots(size):
			var tip: Vector2 = pivot + Vector2(cos(_blade), -sin(_blade)) * _reach(size)
			_page.draw_line(pivot, tip, shine, 13.0)
			_page.draw_line(pivot, tip, MangaType.INK, 8.0)
