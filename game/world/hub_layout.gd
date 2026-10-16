class_name HubLayout
## The barangay hub's layout, in the Babylon hub's units so its plan carries over
## (docs/archive/HUB_LAYOUT.md): x east, z north, metres. `pos` maps to Godot (north is −Z).
##
##   z 200 ┌──── perimeter wall ─────────────────────────────────────────┐
##         │  HOME (NW)          TALYER (N)                              │
##   z 140 │  ╭─────────── barangay street (9 m) ──────────╮  KYO COFFEE │
##         │  │ houses                                      │  (KLMB)     │
##         │  │ SUKI 24        GAS STATION                  │             │
##     z 0 ═══╯════════════ main road (12 m) ═══════════════╧═════ → PASS 1
##   z −60 └─────────────────────────────────────────────────────────────┘
##        x −160                                         120          250

## Loop corners, clockwise from the south-west, driven in this order; traffic keeps right.
const LOOP_CORNERS := [Vector2(-110, 0), Vector2(-110, 140), Vector2(120, 140), Vector2(120, 0)]
## Centreline radius of every loop corner: about 50 km/h at 0.9 g.
const CORNER_RADIUS := 22.0
const LOOP_WIDTH := 9.5
const MAIN_WIDTH := 12.0
const MAIN_FROM := -152.0
const MAIN_TO := 246.0
const BOUNDS := Rect2(-158, -58, 406, 256)

## Where the GLBs' origins sit (see tools/world_builders/).
const KYO_ORIGIN := Vector2(140.6, 101.0)
const TALYER_ORIGIN := Vector2(24.0, 150.0)

## Places: name, area (x0, z0, w, d), and where you start when you come back to them.
const PLACES := {
	"kyo": { "name": "KYO COFFEE", "area": Rect2(124, 84, 41, 30), "spawn": Vector3(130.0, 102.3, 90) },
	"talyer": { "name": "TALYER NI RUEL", "area": Rect2(5, 144, 45, 25), "spawn": Vector3(24, 146.5, 180) },
	"home": { "name": "HOME", "area": Rect2(-90, 145, 24, 27), "spawn": Vector3(-78, 150, 180) },
	"gas": { "name": "BAHANDI FUELS", "area": Rect2(-6, 6, 64, 40), "spawn": Vector3(25, 24, 90) },
	"suki": { "name": "SUKI 24", "area": Rect2(-86, 6, 36, 32), "spawn": Vector3(-71, 13, 180) },
	"exit": { "name": "MAIN ROAD · TO PASS 1", "area": Rect2(200, -8, 46, 16), "spawn": Vector3(210, -3, 90) },
}

## Rivals parked at Kyo: index into VsBattle.RIVALS, then x, z, heading (deg, 0 north, 90 east).
## Nosed in on the apron, like the cars in the photos; Buko's GSR sits down the driveway.
const KYO_PARKED := [
	[0, 129.4, 110.4, 90.0],
	[1, 129.4, 107.3, 90.0],
	[3, 129.4, 93.0, 90.0],
]
## Rivals out cruising the loop (flash your lights behind one to challenge).
const CRUISERS := [2, 4]
## Cruising speed on the barangay roads (m/s): about 40 km/h.
const CRUISE_SPEED := 11.0

## What each rival says when you pull up (Hiligaynon/Taglish, short).
const LINES := {
	"JUNJUN": "Sige, try lang. Pass 1, downhill.",
	"ATE LIZA": "Maasin ta? Basi lang madasig ka na subong.",
	"KAPITAN": "Ikaw na naman? Sige, isa lang.",
	"BUKO": "Basta indi ka maghibi ha.",
	"TISOY": "Ano, bilisan ta? Tara sa bukid.",
}
## Ruel, the mechanic (docs/story: he runs the talyer).
const RUEL := "Unahon ta anay ang preno mo."

## Houses: centre (x, z), footprint (w, d), wall tone, roof tone, facing (deg, 0 north).
const HOUSES := [
	[-77, 164, 18, 12, 0.72, 0.32, 180], [-112, 160, 14, 11, 0.62, 0.42, 180], [-50, 158, 14, 12, 0.66, 0.32, 180],
	[-128, 184, 12, 10, 0.7, 0.36, 90], [-60, 186, 16, 10, 0.6, 0.42, 180], [-92, 118, 16, 12, 0.7, 0.32, 0],
	[-62, 116, 14, 12, 0.62, 0.42, 0], [-5, 160, 14, 12, 0.7, 0.42, 180], [58, 184, 14, 12, 0.6, 0.32, 180],
	[12, 186, 18, 10, 0.72, 0.36, 180], [150, 150, 14, 12, 0.66, 0.42, 270], [95, 165, 16, 12, 0.72, 0.42, 180],
	[-120, -24, 12, 10, 0.7, 0.36, 0], [-92, -26, 14, 10, 0.62, 0.42, 0], [-52, -24, 12, 10, 0.72, 0.32, 0],
	[-20, -27, 16, 10, 0.66, 0.42, 0], [40, -25, 14, 10, 0.6, 0.36, 0], [75, -24, 12, 10, 0.7, 0.42, 0],
	[150, -26, 16, 10, 0.66, 0.32, 0], [185, -24, 12, 10, 0.72, 0.42, 0], [215, -26, 14, 10, 0.62, 0.36, 0],
	[60, 100, 16, 12, 0.66, 0.36, 90], [60, 60, 14, 12, 0.7, 0.42, 90], [-40, 80, 14, 12, 0.62, 0.32, 270],
	[20, 95, 16, 12, 0.72, 0.42, 0], [190, 60, 14, 12, 0.66, 0.36, 270], [200, 120, 16, 12, 0.6, 0.42, 270],
]


## Hub point (x east, z north, height y) → Godot position.
static func pos(x: float, z: float, y := 0.0) -> Vector3:
	return Vector3(x, y, -z)


## Facing in hub degrees (0 north, 90 east) → Godot yaw for a car (forward −Z) or a model.
static func yaw(deg: float) -> float:
	return -deg_to_rad(deg)


## The loop's centreline as a closed polyline in hub (x, z), corners filleted, sampled every
## `spacing` metres; starts on the main road at x = 0 heading west.
static func loop_points(spacing := 1.0) -> PackedVector2Array:
	var raw := PackedVector2Array([Vector2(0, 0)])
	for i in LOOP_CORNERS.size():
		var p: Vector2 = LOOP_CORNERS[i]
		var a: Vector2 = Vector2(0, 0) if i == 0 else LOOP_CORNERS[i - 1]
		var b: Vector2 = Vector2(0, 0) if i == LOOP_CORNERS.size() - 1 else LOOP_CORNERS[i + 1]
		var d1 := (a - p).normalized()
		var d2 := (b - p).normalized()
		var half := d1.angle_to(d2) * 0.5
		var t := CORNER_RADIUS / tan(absf(half))
		var center := p + (d1 + d2).normalized() * CORNER_RADIUS / sin(absf(half))
		var from := (p + d1 * t - center).angle()
		var to := (p + d2 * t - center).angle()
		var sweep := wrapf(to - from, -PI, PI)
		for k in 13:
			raw.append(center + Vector2.from_angle(from + sweep * k / 12.0) * CORNER_RADIUS)
	raw.append(Vector2(0, 0))
	# Resample at even spacing.
	var out := PackedVector2Array([raw[0]])
	var carry := 0.0
	for i in range(1, raw.size()):
		var a := raw[i - 1]
		var seg := raw[i] - a
		var length := seg.length()
		var s := spacing - carry
		while s <= length:
			out.append(a + seg * (s / length))
			s += spacing
		carry = length - (s - spacing)
	return out


## The loop as a road the game can drive: `laps` times round, so the cruisers' look-ahead never
## runs off the end (they rebase a lap back as they go).
static func loop_track(laps := 1) -> TrackData:
	var ring := loop_points()
	ring.remove_at(ring.size() - 1)
	var t := TrackData.new()
	t.spacing = 1.0
	t.half_width = LOOP_WIDTH * 0.5
	var n := ring.size()
	for i in n * laps + 1:
		var p := ring[i % n]
		var q := ring[(i + 1) % n]
		var f := Vector3(q.x - p.x, 0, -(q.y - p.y)).normalized()
		t.points.append(pos(p.x, p.y))
		t.forwards.append(f)
		t.rights.append(f.cross(Vector3.UP).normalized())
	t.start_distance = 0.0
	t.finish_distance = t.length()
	return t
