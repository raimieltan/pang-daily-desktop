extends RefCounted
## Watches the cars in a trailer take and writes what happened, with timestamps, so the edit
## can cut to real moments: overtakes (order along the road changes between two close cars),
## powerslides (body slip held past a threshold at speed) and the camera cuts the shot made.

const SLIDE_ON := 12.0     # deg of body slip that opens a slide
const SLIDE_OFF := 7.0
const SLIDE_MIN_KMH := 35.0
const SLIDE_MIN_SECONDS := 0.4
const PASS_GAP := 15.0     # m; a bigger jump in order is a respawn, not a pass
const PASS_MARGIN := 2.0   # m clear before a pass counts (distances are 1 m samples)

var track: TrackData
var cars: Array = []
var names: Array = []
var overtakes: Array = []
var slides: Array = []
var cuts: Array = []
var marks: Array = []
var samples: Array = []
var _hints := {}
var _ahead := {}           # Vector2i(a, b) -> true while a leads b
var _open := {}            # car index -> slide in progress
var _next_sample := 0.0


func watch(cars_: Array, names_: Array) -> void:
	cars = cars_
	names = names_
	_ahead.clear()
	_open.clear()


func distance(i: int) -> float:
	var car: CarBody = cars[i]
	_hints[i] = track.nearest_index(car.global_position, _hints.get(i, 0))
	return _hints[i] * track.spacing


func cut(t: float, shot: String, focus: String) -> void:
	cuts.append({ "t": snappedf(t, 0.001), "shot": shot, "focus": focus })


func mark(t: float, what: String) -> void:
	marks.append({ "t": snappedf(t, 0.001), "what": what })


func step(t: float) -> void:
	if cars.is_empty():
		return
	var d := []
	for i in cars.size():
		d.append(distance(i))
	for a in cars.size():
		for b in range(a + 1, cars.size()):
			var lead: float = d[a] - d[b]
			var key := Vector2i(a, b)
			if not _ahead.has(key):
				_ahead[key] = lead >= 0.0
			elif absf(lead) > PASS_MARGIN and (lead > 0.0) != _ahead[key]:
				_ahead[key] = lead > 0.0
				if absf(lead) < PASS_GAP:
					var by := a if lead > 0.0 else b
					var on := b if lead > 0.0 else a
					overtakes.append({ "t": snappedf(t, 0.001), "by": names[by], "on": names[on],
						"player": by == 0 or on == 0, "at_m": snappedf(d[by], 0.1) })
	for i in cars.size():
		var car: CarBody = cars[i]
		var slip := absf(rad_to_deg(car.model.diagnostics.body_slip))
		var kmh := car.linear_velocity.length() * 3.6
		if not _open.has(i) and slip > SLIDE_ON and kmh > SLIDE_MIN_KMH:
			_open[i] = { "car": names[i], "t0": t, "max_slip": slip, "kmh": kmh }
		elif _open.has(i):
			var s: Dictionary = _open[i]
			s["max_slip"] = maxf(s["max_slip"], slip)
			if slip < SLIDE_OFF or kmh < SLIDE_MIN_KMH * 0.6:
				if t - s["t0"] >= SLIDE_MIN_SECONDS:
					slides.append({ "car": s["car"], "t0": snappedf(s["t0"], 0.001), "t1": snappedf(t, 0.001),
						"max_slip": snappedf(s["max_slip"], 0.1), "kmh": roundi(s["kmh"]) })
				_open.erase(i)
	if t >= _next_sample:
		_next_sample = t + 0.5
		var row := { "t": snappedf(t, 0.01) }
		for i in cars.size():
			row[names[i]] = [snappedf(d[i], 0.1), roundi(cars[i].linear_velocity.length() * 3.6)]
		samples.append(row)


func save(path: String, meta: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	var out := meta.duplicate()
	out.merge({ "overtakes": overtakes, "slides": slides, "cuts": cuts, "marks": marks, "samples": samples })
	f.store_string(JSON.stringify(out, "  "))
	print("events: %d overtakes, %d slides, %d cuts -> %s" % [overtakes.size(), slides.size(), cuts.size(), path])
