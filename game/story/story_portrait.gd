class_name StoryPortrait
extends Control
## The speaker's face in the speech panel: a manga bust in ink and paper, drawn in code on a
## 200-unit square (scaled to the control). Each speaker has a LOOK (hair, clothes, eyes, mouth,
## extras); narration and unknown speakers have no portrait. Pang carries the crash from Act II
## on: a scar at the brow and tired eyes.

const INK := MangaType.INK
const PAPER := MangaType.PAPER
const TONE := Color(0.42, 0.42, 0.42)

## hair: messy | cap_back | side | towel | slick | buzz | wavy | beanie | ponytail | bun | grey | hood | cap
## wear: tee | jacket | overall | overshirt | hoodie | blouse | polo
## eyes: plain | sharp | soft | big | narrow     mouth: flat | grin | smirk | frown | open
## extras: strap, stubble, moustache, glasses, lines, freckles
const LOOKS := {
	"PANG": { "hair": "messy", "wear": "tee", "eyes": "plain", "mouth": "flat", "extras": [] },
	"JOLO": { "hair": "cap_back", "wear": "tee", "eyes": "big", "mouth": "grin", "extras": ["strap"] },
	"NICO": { "hair": "side", "wear": "jacket", "eyes": "sharp", "mouth": "flat", "extras": [] },
	"RUEL": { "hair": "towel", "wear": "overall", "eyes": "narrow", "mouth": "frown", "extras": ["stubble", "lines"] },
	"DANTE": { "hair": "slick", "wear": "overshirt", "eyes": "narrow", "mouth": "smirk", "extras": ["moustache"] },
	"KAPITAN": { "hair": "cap", "wear": "polo", "eyes": "narrow", "mouth": "grin", "extras": ["lines"] },
	"BUKO": { "hair": "buzz", "wear": "tee", "eyes": "soft", "mouth": "flat", "extras": [] },
	"TISOY": { "hair": "wavy", "wear": "polo", "eyes": "plain", "mouth": "smirk", "extras": [] },
	"RJ": { "hair": "beanie", "wear": "hoodie", "eyes": "plain", "mouth": "open", "extras": ["freckles"] },
	"ATE LIZA": { "hair": "ponytail", "wear": "blouse", "eyes": "soft", "mouth": "flat", "extras": [] },
	"JOLO'S MOTHER": { "hair": "bun", "wear": "blouse", "eyes": "soft", "mouth": "frown", "extras": ["lines"] },
	"JOLO'S FATHER": { "hair": "grey", "wear": "polo", "eyes": "narrow", "mouth": "frown", "extras": ["glasses", "lines"] },
	"WITNESS": { "hair": "hood", "wear": "hoodie", "eyes": "plain", "mouth": "flat", "extras": [] },
	"KID": { "hair": "messy", "wear": "hoodie", "eyes": "big", "mouth": "open", "extras": [] },
}

## No paper square, tone or frame: the face drawn straight onto a comic panel.
var bare := false

var _look := {}
var _scarred := false


## Show `who`; false when there is no portrait for them (narration, unknown speakers, Jolo in
## the present: his face is a memory).
func show_speaker(who: String) -> bool:
	_look = LOOKS.get(who.strip_edges(), {}) if has_face(who, StoryMode.beat) else {}
	_scarred = who == "PANG" and scarred_at(StoryMode.beat)
	visible = not _look.is_empty()
	queue_redraw()
	return visible


## Pang carries the crash in the present, from the clinic on: not in the prologue (the crash
## itself) and not inside a memory.
static func scarred_at(index: int) -> bool:
	return StoryScript.memory_of(index) == "" and index >= StoryScript.index_of("a1_card")


## Jolo's face appears only while he is alive: inside a memory, and in the prologue (the crash
## night itself); present-day JOLO lines are footage.
static func has_face(who: String, index: int) -> bool:
	var name := who.strip_edges()
	if not LOOKS.has(name):
		return false
	return name != "JOLO" or StoryScript.memory_of(index) != "" or index < StoryScript.index_of("a1_card")


func _draw() -> void:
	if _look.is_empty():
		return
	var s := minf(size.x, size.y) / 200.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	if not bare:
		draw_rect(Rect2(0, 0, 200, 200), PAPER)
		_tone_corner()
	var hair: String = _look["hair"]
	if hair == "hood":
		_hood_back()
	if hair == "ponytail":
		draw_colored_polygon(PackedVector2Array([Vector2(130, 70), Vector2(160, 92), Vector2(166, 140),
			Vector2(150, 160), Vector2(146, 118), Vector2(128, 96)]), INK)
	if hair == "bun":
		_blob(Vector2(100, 34), 18, 16, TONE)
	_body()
	# Ears, then the head over them.
	for x in [58.0, 142.0]:
		_blob(Vector2(x, 98), 8, 12, PAPER)
	draw_colored_polygon(_head(), PAPER)
	draw_polyline(_closed(_head()), INK, 3.0, true)
	_hair(hair)
	_face()
	if hair == "hood":
		_hood_front()
	if hair == "cap":
		_cap_front()
	if not bare:
		draw_rect(Rect2(0, 0, 200, 200), INK, false, 5.0)
	draw_set_transform(Vector2.ZERO)


func _tone_corner() -> void:
	# A dot screentone falling off from the top right: the panel is not a flat card.
	var y := 6.0
	while y < 120.0:
		var x := 200.0 - 6.0 - fmod(y / 9.0, 2.0) * 4.5
		while x > 80.0 + y:
			var r := 2.2 * (1.0 - (y + (200.0 - x)) / 240.0)
			if r > 0.3:
				draw_circle(Vector2(x, y), r, Color(INK, 0.5))
			x -= 9.0
		y += 9.0


# --- Head -------------------------------------------------------------------------------------


## Face outline: round crown, the jaw narrowing to a chin.
func _head() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := Vector2(100, 92)
	for i in 28:
		var t := TAU * i / 28.0
		var down := maxf(0.0, sin(t))
		var x := cos(t) * 40.0 * (1.0 - 0.32 * down * down)
		var y := sin(t) * (46.0 + 10.0 * down)
		pts.append(c + Vector2(x, y))
	return pts


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	out.append(p[0])
	return out


func _blob(c: Vector2, rx: float, ry: float, fill: Color, line := 3.0) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	draw_colored_polygon(pts, fill)
	if line > 0.0:
		draw_polyline(_closed(pts), INK, line, true)


## A cap of hair over the crown, from `left` to `right` (radians round the head), fringe at `brow`.
func _crown(lift: float, brow: float, spikes: int, spike: float, fill: Color) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := Vector2(100, 92)
	var n := 22
	for i in n + 1:
		var t := PI * 0.94 + PI * 1.12 * i / n
		var r := 1.0 + lift + (spike if spikes > 0 and i % 2 == 1 else 0.0)
		pts.append(c + Vector2(cos(t) * 40.0 * r, sin(t) * 46.0 * r))
	# Sideburns in to the temples, then the fringe back across the forehead, jagged when spiky.
	var half := 40.0 * cos(asin(clampf((c.y - brow) / 46.0, -1.0, 1.0))) - 6.0
	var bottom := pts[0].y
	pts.append(Vector2(c.x + half + 4.0, bottom))
	var m := maxi(spikes, 2)
	for i in m + 1:
		var x := lerpf(c.x + half, c.x - half, float(i) / m)
		var y := brow + (8.0 if spikes > 0 and i % 2 == 1 else 0.0)
		pts.append(Vector2(x, y))
	pts.append(Vector2(c.x - half - 4.0, bottom))
	draw_colored_polygon(pts, fill)
	draw_polyline(_closed(pts), INK, 3.0, true)
	return pts


func _hair(kind: String) -> void:
	match kind:
		"messy":
			_crown(0.12, 66, 7, 0.14, INK)
			_shine(Vector2(84, 54))
		"cap_back":
			_crown(0.06, 64, 5, 0.1, INK)
			# A cap worn backwards: the dome, and the strap gap over the forehead.
			var dome := PackedVector2Array()
			for i in 17:
				var t := PI + PI * i / 16.0
				dome.append(Vector2(100, 70) + Vector2(cos(t) * 46.0, sin(t) * 34.0))
			draw_colored_polygon(dome, TONE)
			draw_polyline(dome, INK, 3.0, true)
			draw_line(Vector2(54, 70), Vector2(146, 70), INK, 4.0)
			draw_arc(Vector2(100, 70), 11, PI, TAU, 10, INK, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(89, 70), Vector2(111, 70), Vector2(108, 62), Vector2(92, 62)]), PAPER)
		"side":
			_crown(0.08, 62, 0, 0.0, INK)
			draw_line(Vector2(80, 50), Vector2(76, 62), PAPER, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(78, 62), Vector2(140, 60), Vector2(138, 76), Vector2(110, 64)]), INK)
			_shine(Vector2(112, 52))
		"towel":
			_crown(0.05, 62, 0, 0.0, INK)
			# A towel tied round the head, the knot at the side.
			draw_colored_polygon(PackedVector2Array([Vector2(58, 58), Vector2(142, 58), Vector2(144, 72), Vector2(56, 72)]), PAPER)
			draw_polyline(PackedVector2Array([Vector2(58, 58), Vector2(142, 58), Vector2(144, 72), Vector2(56, 72), Vector2(58, 58)]), INK, 3.0)
			for x in [72.0, 92.0, 112.0, 130.0]:
				draw_line(Vector2(x, 60), Vector2(x - 4, 70), INK, 1.5)
			_blob(Vector2(148, 66), 7, 6, PAPER)
			draw_colored_polygon(PackedVector2Array([Vector2(152, 68), Vector2(166, 84), Vector2(156, 86)]), PAPER)
			draw_polyline(PackedVector2Array([Vector2(152, 68), Vector2(166, 84), Vector2(156, 86), Vector2(152, 68)]), INK, 2.0)
		"slick":
			_crown(0.1, 54, 0, 0.0, INK)
			for i in 4:
				draw_line(Vector2(82 + i * 10, 52), Vector2(94 + i * 12, 44), PAPER, 1.6)
		"buzz":
			_crown(0.03, 58, 0, 0.0, TONE)
		"wavy":
			_crown(0.1, 64, 6, 0.08, TONE)
			for i in 3:
				draw_arc(Vector2(84 + i * 16, 50), 7, PI * 0.1, PI * 0.9, 6, INK, 1.8)
		"beanie":
			var dome := PackedVector2Array()
			for i in 17:
				var t := PI + PI * i / 16.0
				dome.append(Vector2(100, 70) + Vector2(cos(t) * 46.0, sin(t) * 40.0))
			draw_colored_polygon(dome, INK)
			for i in 7:
				draw_line(Vector2(64 + i * 12, 64), Vector2(70 + i * 10, 40), Color(PAPER, 0.5), 1.5)
			draw_rect(Rect2(52, 62, 96, 14), TONE)
			draw_rect(Rect2(52, 62, 96, 14), INK, false, 3.0)
		"ponytail":
			_crown(0.05, 60, 0, 0.0, INK)
			draw_line(Vector2(100, 46), Vector2(70, 66), PAPER, 1.5)
		"bun":
			_crown(0.04, 60, 0, 0.0, TONE)
			draw_line(Vector2(100, 46), Vector2(100, 60), INK, 1.5)
		"grey":
			_crown(0.04, 58, 4, 0.05, Color(0.7, 0.7, 0.7))
		"cap":
			_crown(0.04, 66, 0, 0.0, INK)
		"hood":
			_crown(0.04, 62, 5, 0.08, INK)


func _shine(at: Vector2) -> void:
	draw_line(at, at + Vector2(14, -4), PAPER, 2.0)
	draw_line(at + Vector2(4, 6), at + Vector2(16, 2), PAPER, 1.5)


func _cap_front() -> void:
	var dome := PackedVector2Array()
	for i in 17:
		var t := PI + PI * i / 16.0
		dome.append(Vector2(100, 66) + Vector2(cos(t) * 45.0, sin(t) * 32.0))
	draw_colored_polygon(dome, PAPER)
	draw_polyline(dome, INK, 3.0, true)
	draw_rect(Rect2(88, 44, 24, 12), Color(INK, 0.85))
	# The brim, shading the eyes.
	var brim := PackedVector2Array([Vector2(50, 66), Vector2(150, 66), Vector2(140, 80), Vector2(60, 80)])
	draw_colored_polygon(brim, INK)


func _hood_back() -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var t := PI * 0.85 + PI * 1.3 * i / 24.0
		pts.append(Vector2(100, 100) + Vector2(cos(t) * 58.0, sin(t) * 66.0))
	pts.append(Vector2(168, 200))
	pts.append(Vector2(32, 200))
	draw_colored_polygon(pts, INK)


func _hood_front() -> void:
	# Shadow of the hood over the upper face.
	draw_colored_polygon(PackedVector2Array([Vector2(60, 62), Vector2(140, 62), Vector2(136, 84), Vector2(64, 84)]), Color(INK, 0.55))


# --- Face -------------------------------------------------------------------------------------


func _face() -> void:
	var extras: Array = _look["extras"]
	var eyes: String = _look["eyes"]
	if _scarred:
		eyes = "tired"
	for side in [-1.0, 1.0]:
		_eye(Vector2(100 + side * 19.0, 98), side, eyes)
	# Nose: a short ink tick and its shadow.
	draw_polyline(PackedVector2Array([Vector2(101, 104), Vector2(98, 116), Vector2(103, 117)]), INK, 2.0)
	_mouth(_look["mouth"])
	if "stubble" in extras:
		for i in 26:
			var a := PI * 0.15 + PI * 0.7 * i / 25.0
			draw_circle(Vector2(100, 112) + Vector2(cos(a) * 30.0, sin(a) * 30.0), 1.1, INK)
	if "moustache" in extras:
		draw_colored_polygon(PackedVector2Array([Vector2(86, 124), Vector2(100, 120), Vector2(114, 124), Vector2(108, 127), Vector2(100, 125), Vector2(92, 127)]), INK)
	if "glasses" in extras:
		for x in [81.0, 119.0]:
			draw_arc(Vector2(x, 98), 13, 0, TAU, 18, INK, 2.5)
		draw_line(Vector2(94, 97), Vector2(106, 97), INK, 2.5)
	if "lines" in extras:
		for y in [66.0, 72.0]:
			draw_line(Vector2(86, y + 4), Vector2(114, y + 4), Color(INK, 0.6), 1.2)
		for side in [-1.0, 1.0]:
			draw_line(Vector2(100 + side * 24.0, 112), Vector2(100 + side * 20.0, 124), Color(INK, 0.6), 1.2)
	if "freckles" in extras:
		for p in [Vector2(80, 110), Vector2(85, 113), Vector2(90, 110), Vector2(110, 110), Vector2(115, 113), Vector2(120, 110)]:
			draw_circle(p, 1.2, INK)
	if "strap" in extras:
		draw_colored_polygon(PackedVector2Array([Vector2(56, 152), Vector2(66, 148), Vector2(150, 200), Vector2(134, 200)]), PAPER)
		draw_polyline(PackedVector2Array([Vector2(56, 152), Vector2(134, 200)]), INK, 2.5)
		draw_polyline(PackedVector2Array([Vector2(66, 148), Vector2(150, 200)]), INK, 2.5)
	if _scarred:
		# The crash: a scar through the left brow.
		draw_line(Vector2(72, 80), Vector2(84, 92), INK, 2.5)
		for i in 3:
			var p := Vector2(72, 80).lerp(Vector2(84, 92), 0.2 + i * 0.3)
			draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), INK, 1.4)


func _eye(c: Vector2, side: float, kind: String) -> void:
	var brow_tilt := 0.0
	match kind:
		"sharp":
			brow_tilt = 5.0
		"narrow":
			brow_tilt = 3.0
		"soft":
			brow_tilt = -3.0
		"tired":
			brow_tilt = -2.0
	# Brow: thick, tilted toward the nose when stern.
	var inner := c + Vector2(-side * 9.0, -14.0 + brow_tilt)
	var outer := c + Vector2(side * 11.0, -16.0)
	draw_line(inner, outer, INK, 4.0)
	match kind:
		"big":
			_blob(c, 8, 10, PAPER, 2.5)
			_blob(c + Vector2(0, 2), 5, 7, INK, 0.0)
			draw_circle(c + Vector2(-2, -2), 2.2, PAPER)
			draw_line(c + Vector2(-10, -9), c + Vector2(10, -9), INK, 3.5)
		"sharp", "narrow":
			var h := 2.5 if kind == "narrow" else 4.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(-11, 0), c + Vector2(side * 2.0, -h - 2.0),
				c + Vector2(11, 0), c + Vector2(0, h)]), INK)
			draw_circle(c + Vector2(-1, -1), 1.4, PAPER)
		"soft":
			draw_arc(c + Vector2(0, 2), 8, PI * 1.1, PI * 1.9, 8, INK, 3.5)
			draw_circle(c + Vector2(0, 2), 3.0, INK)
		"tired":
			draw_line(c + Vector2(-10, -2), c + Vector2(10, -3), INK, 3.5)
			draw_circle(c + Vector2(0, 1), 3.2, INK)
			draw_arc(c + Vector2(0, 4), 8, PI * 0.15, PI * 0.85, 6, Color(INK, 0.6), 1.4)
		_:
			draw_line(c + Vector2(-10, -3), c + Vector2(10, -3), INK, 3.5)
			_blob(c + Vector2(0, 1), 4, 5, INK, 0.0)
			draw_circle(c + Vector2(-1.5, -0.5), 1.4, PAPER)


func _mouth(kind: String) -> void:
	var c := Vector2(100, 130)
	match kind:
		"grin":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -3), c + Vector2(13, -3), c + Vector2(8, 6), c + Vector2(-8, 6)]), INK)
			draw_rect(Rect2(c + Vector2(-11, -3), Vector2(22, 3)), PAPER)
		"smirk":
			draw_polyline(PackedVector2Array([c + Vector2(-9, 1), c + Vector2(4, 1), c + Vector2(11, -4)]), INK, 2.5)
		"frown":
			draw_arc(c + Vector2(0, 7), 9, PI * 1.2, PI * 1.8, 6, INK, 2.5)
		"open":
			_blob(c + Vector2(0, 1), 5, 4, INK, 0.0)
		_:
			draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), INK, 2.5)


# --- Body -------------------------------------------------------------------------------------


func _body() -> void:
	var wear: String = _look["wear"]
	# Neck.
	draw_rect(Rect2(86, 130, 28, 30), PAPER)
	draw_line(Vector2(86, 130), Vector2(86, 158), INK, 3.0)
	draw_line(Vector2(114, 130), Vector2(114, 158), INK, 3.0)
	var shoulders := PackedVector2Array([Vector2(10, 200), Vector2(22, 168), Vector2(60, 152), Vector2(86, 150),
		Vector2(100, 160), Vector2(114, 150), Vector2(140, 152), Vector2(178, 168), Vector2(190, 200)])
	var fill: Color = { "tee": PAPER, "jacket": INK, "overall": TONE, "overshirt": INK, "hoodie": INK,
		"blouse": PAPER, "polo": TONE }.get(wear, PAPER)
	draw_colored_polygon(shoulders, fill)
	draw_polyline(shoulders, INK if fill != INK else PAPER, 3.0, true)
	match wear:
		"tee":
			draw_arc(Vector2(100, 150), 16, 0.15, PI - 0.15, 10, INK, 3.0)
		"jacket":
			# High collar, a zip, a racing stripe down the shoulder.
			draw_colored_polygon(PackedVector2Array([Vector2(80, 146), Vector2(120, 146), Vector2(124, 166), Vector2(76, 166)]), INK)
			draw_polyline(PackedVector2Array([Vector2(80, 146), Vector2(76, 166), Vector2(124, 166), Vector2(120, 146)]), PAPER, 2.0)
			draw_line(Vector2(100, 166), Vector2(100, 200), PAPER, 2.0)
			draw_line(Vector2(40, 160), Vector2(26, 200), PAPER, 5.0)
			draw_line(Vector2(160, 160), Vector2(174, 200), PAPER, 5.0)
		"overall":
			draw_colored_polygon(PackedVector2Array([Vector2(84, 150), Vector2(116, 150), Vector2(108, 170), Vector2(92, 170)]), INK)
			for x in [70.0, 130.0]:
				draw_line(Vector2(x, 154), Vector2(x, 200), INK, 4.0)
				draw_circle(Vector2(x, 176), 3.5, PAPER)
		"overshirt":
			draw_colored_polygon(PackedVector2Array([Vector2(86, 150), Vector2(114, 150), Vector2(100, 186)]), PAPER)
			draw_polyline(PackedVector2Array([Vector2(72, 150), Vector2(100, 190), Vector2(128, 150)]), PAPER, 2.5)
		"hoodie":
			draw_arc(Vector2(100, 152), 26, 0.1, PI - 0.1, 12, PAPER, 2.5)
			for x in [92.0, 108.0]:
				draw_line(Vector2(x, 170), Vector2(x, 194), PAPER, 2.0)
		"blouse":
			draw_arc(Vector2(100, 150), 20, 0.2, PI - 0.2, 10, INK, 3.0)
			for p in [Vector2(100, 178), Vector2(100, 192)]:
				draw_circle(p, 2.2, INK)
		"polo":
			draw_colored_polygon(PackedVector2Array([Vector2(84, 150), Vector2(100, 164), Vector2(90, 172), Vector2(76, 156)]), PAPER)
			draw_colored_polygon(PackedVector2Array([Vector2(116, 150), Vector2(100, 164), Vector2(110, 172), Vector2(124, 156)]), PAPER)
			draw_line(Vector2(100, 164), Vector2(100, 186), INK, 2.0)
