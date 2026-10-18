class_name StoryComic
extends Control
## A manga page between scenes: up to four panels on paper, landing one per press, each with its
## art, a caption box, a speech bubble and a sound word. StoryDialogue.comic() plays the pages.
##
## A page is an Array of panels (1–4; the layout follows the count). A panel is a Dictionary:
##   art   "face" (the speaker's portrait) | "snap" (the scene behind the page, frozen) | "speed"
##         (focus lines) | "rain" | "wipers" | "lights" (headlights in the dark) | "road" (a night
##         road in perspective) | "tone" (screentone round a clear centre) | "black" | "white"
##   who   speaker (the face for "face"; a name tag on the bubble otherwise)
##   say   speech bubble text        cap   caption box text        fx   a big sound word
##   side  "left" | "right": where the face sits (default alternates)
##   sfx   StoryDialogue.SFX name played when the panel lands

const INK := MangaType.INK
const PAPER := MangaType.PAPER
const MARGIN := 26.0
const GUTTER := 14.0

## The scene behind the page, for "snap" panels (null: they fall back to screentone).
var snap: Texture2D
## Whether the page is waiting for a press (the hint pulses).
var waiting := false

var _page: Array = []
var _rects: Array[Rect2] = []
var _shown := 0
var _arts: Array[PanelArt] = []
var _overlay: Overlay


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay = Overlay.new()
	_overlay.comic = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)


func _process(_delta: float) -> void:
	if visible:
		_overlay.queue_redraw()


## Lay out a new page with every panel still blank.
func show_page(page: Array) -> void:
	for a in _arts:
		a.queue_free()
	_arts.clear()
	_page = page
	# Sized from the viewport: anchors on a hidden Control under a CanvasLayer leave it at zero.
	size = get_viewport_rect().size
	_overlay.size = size
	_rects = layout(page.size(), size)
	_shown = 0
	for i in page.size():
		var a := PanelArt.new()
		a.panel = page[i]
		a.snap = snap
		a.index = i
		a.position = _rects[i].position
		a.size = _rects[i].size
		a.visible = false
		add_child(a)
		move_child(a, _overlay.get_index())
		_arts.append(a)
	queue_redraw()


## Land panel `i`: it drops in from a few pixels up and fades in.
func reveal(i: int) -> void:
	_shown = i + 1
	var a := _arts[i]
	a.visible = true
	a.modulate.a = 0.0
	a.position = _rects[i].position + Vector2(0, -10)
	var tw := create_tween().set_parallel()
	tw.tween_property(a, "modulate:a", 1.0, 0.18)
	tw.tween_property(a, "position", _rects[i].position, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Panel rects for `n` panels on a page of `page` size: a wide strip over two, two side by side,
## or a staggered four.
static func layout(n: int, page: Vector2) -> Array[Rect2]:
	var inner := Rect2(Vector2(MARGIN, MARGIN), page - Vector2(MARGIN, MARGIN) * 2.0)
	var out: Array[Rect2] = []
	var w := inner.size.x
	var h := inner.size.y
	var o := inner.position
	match n:
		1:
			out.append(inner)
		2:
			var a := w * 0.56
			out.append(Rect2(o, Vector2(a - GUTTER * 0.5, h)))
			out.append(Rect2(o + Vector2(a + GUTTER * 0.5, 0), Vector2(w - a - GUTTER * 0.5, h)))
		3:
			var top := h * 0.46
			var a := w * 0.42
			var bh := h - top - GUTTER
			out.append(Rect2(o, Vector2(w, top)))
			out.append(Rect2(o + Vector2(0, top + GUTTER), Vector2(a - GUTTER * 0.5, bh)))
			out.append(Rect2(o + Vector2(a + GUTTER * 0.5, top + GUTTER), Vector2(w - a - GUTTER * 0.5, bh)))
		_:
			var top := (h - GUTTER) * 0.5
			for row in 2:
				var a := w * (0.6 if row == 0 else 0.4)
				var y := o.y + row * (top + GUTTER)
				out.append(Rect2(Vector2(o.x, y), Vector2(a - GUTTER * 0.5, top)))
				out.append(Rect2(Vector2(o.x + a + GUTTER * 0.5, y), Vector2(w - a - GUTTER * 0.5, top)))
			out.resize(mini(n, 4))
	return out


## One panel's art, clipped to its frame (the portrait for "face" panels is a child).
class PanelArt extends Control:
	var panel := {}
	var snap: Texture2D
	var index := 0
	var _portrait: StoryPortrait

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if panel.get("art", "") == "face":
			_portrait = StoryPortrait.new()
			_portrait.bare = true
			_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_portrait)
			_portrait.show_speaker(str(panel.get("who", "")))
			resized.connect(_place_face)
			_place_face()

	## The face fills the panel's height on its side, cut off at the shoulders by the frame.
	func _place_face() -> void:
		var side := face_size()
		_portrait.size = Vector2(side, side)
		_portrait.position = Vector2(size.x - side * 0.96 if face_right() else -side * 0.04, size.y - side * 0.9)

	## The face's square, kept to its side so the bubble has the rest of the panel.
	func face_size() -> float:
		return minf(size.y * 1.0, size.x * 0.6)

	## Where the mouth is, in panel coordinates (StoryPortrait draws on a 200-unit square).
	func mouth() -> Vector2:
		var side := face_size()
		var x := size.x - side * 0.96 if face_right() else -side * 0.04
		return Vector2(x, size.y - side * 0.9) + Vector2(100, 140) / 200.0 * side

	func face_right() -> bool:
		return panel.get("side", "right" if index % 2 == 1 else "left") == "right"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		match panel.get("art", "tone"):
			"black":
				draw_rect(r, INK)
			"white":
				_vignette(r, 0.18, false)
			"snap":
				if snap:
					_snap(r)
				else:
					_vignette(r)
			"speed":
				draw_rect(r, PAPER)
				_speed(r)
			"rain":
				draw_rect(r, Color(0.2, 0.2, 0.2))
				_rain(r)
			"wipers":
				draw_rect(r, Color(0.2, 0.2, 0.2))
				_rain(r)
				_wiper(r)
			"lights":
				draw_rect(r, INK)
				_lights(r)
			"road":
				draw_rect(r, INK)
				_road(r)
			"face":
				_tone(r, 0.5)
				_speed_soft(r)
			_:
				_vignette(r)

	func _snap(r: Rect2) -> void:
		# Centre crop of the frozen scene at the panel's aspect.
		var ts := Vector2(snap.get_size())
		var aspect := r.size.x / r.size.y
		var src := Rect2(Vector2.ZERO, ts)
		if ts.x / ts.y > aspect:
			src.size.x = ts.y * aspect
			src.position.x = (ts.x - src.size.x) * 0.5
		else:
			src.size.y = ts.x / aspect
			src.position.y = (ts.y - src.size.y) * 0.5
		draw_texture_rect_region(snap, r, src)

	## Paper with a dot screentone falling off from one corner (`from` 0 top .. 1 bottom).
	func _tone(r: Rect2, from: float) -> void:
		draw_rect(r, PAPER)
		var step := 11.0
		var y := 0.0
		while y < r.size.y:
			var t := y / r.size.y
			var k := absf(t - from)
			var rad := 2.4 * (1.0 - k)
			if rad > 0.3:
				var x := fmod(y / step, 2.0) * step * 0.5
				while x < r.size.x:
					draw_circle(Vector2(x, y), rad, Color(INK, 0.25))
					x += step
			y += step

	## A caption panel with nothing to show: screentone thickening toward the frame round a clear
	## centre, and a few soft lines drawn in, so it reads as a drawn mood, not an empty box.
	func _vignette(r: Rect2, ink := 0.55, lines := true) -> void:
		draw_rect(r, PAPER)
		var c := r.get_center()
		var reach := r.size.length() * 0.5
		var step := 10.0
		var y := 0.0
		while y < r.size.y:
			var x := fmod(y / step, 2.0) * step * 0.5
			while x < r.size.x:
				var k := clampf(Vector2(x, y).distance_to(c) / reach * 1.35 - 0.3, 0.0, 1.0)
				if k > 0.05:
					draw_circle(Vector2(x, y), 3.6 * k, Color(INK, ink))
				x += step
			y += step
		if lines:
			_speed_soft(r)

	## Focus lines: ink wedges from the frame toward a clear centre.
	func _speed(r: Rect2) -> void:
		var c := r.get_center()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + index
		var far := r.size.length()
		var clear := minf(r.size.x, r.size.y) * 0.32
		for k in 90:
			var ang := rng.randf() * TAU
			var dir := Vector2.from_angle(ang)
			var near := clear * rng.randf_range(0.9, 1.6)
			var wide := rng.randf_range(0.004, 0.016)
			var side := dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([c + dir * near, c + dir * far + side * far * wide,
				c + dir * far - side * far * wide]), INK)

	## Faint focus lines behind a face.
	func _speed_soft(r: Rect2) -> void:
		var c := r.get_center()
		var rng := RandomNumberGenerator.new()
		rng.seed = 31 + index
		var far := r.size.length()
		for k in 40:
			var dir := Vector2.from_angle(rng.randf() * TAU)
			var near := minf(r.size.x, r.size.y) * rng.randf_range(0.45, 0.8)
			draw_line(c + dir * near, c + dir * far, Color(INK, 0.35), rng.randf_range(1.0, 2.5))

	func _rain(r: Rect2) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 13 + index
		var slant := Vector2(-0.28, 1.0).normalized()
		for k in int(r.size.x * r.size.y / 900.0):
			var p := Vector2(rng.randf() * (r.size.x + 80.0), rng.randf() * r.size.y)
			var l := rng.randf_range(14.0, 46.0)
			draw_line(p, p + slant * l, Color(PAPER, rng.randf_range(0.35, 0.85)), rng.randf_range(1.0, 2.2))
		# Drops on the glass.
		for k in 26:
			var p := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
			var rad := rng.randf_range(2.5, 6.0)
			draw_circle(p, rad, Color(PAPER, 0.75))
			draw_arc(p, rad, 0.0, TAU, 12, INK, 1.2)

	func _wiper(r: Rect2) -> void:
		# One blade mid-sweep from the bottom left, and the cleared fan behind it.
		var pivot := Vector2(r.size.x * 0.18, r.size.y * 1.05)
		var reach := r.size.y * 1.15
		var ang := -1.05
		draw_colored_polygon(PackedVector2Array([pivot, pivot + Vector2.from_angle(-1.75) * reach,
			pivot + Vector2.from_angle(ang) * reach]), Color(0.1, 0.1, 0.1))
		draw_line(pivot, pivot + Vector2.from_angle(ang) * reach, INK, 12.0)
		draw_line(pivot + Vector2.from_angle(ang) * reach * 0.3, pivot + Vector2.from_angle(ang) * reach, Color(0.3, 0.3, 0.3), 4.0)

	func _lights(r: Rect2) -> void:
		# Two headlamps glaring through trees: soft rings, a hard core, a flare across the frame.
		var y := r.size.y * 0.55
		for x in [r.size.x * 0.4, r.size.x * 0.62]:
			var c := Vector2(x, y)
			for k in range(10, 0, -1):
				draw_circle(c, k * r.size.y * 0.05, Color(MangaArt.HEADLAMP, 0.06))
			draw_circle(c, r.size.y * 0.05, PAPER)
		draw_line(Vector2(0, y), Vector2(r.size.x, y), Color(PAPER, 0.6), 2.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5 + index
		for k in 9:
			var x := rng.randf() * r.size.x
			draw_line(Vector2(x, 0), Vector2(x + rng.randf_range(-20, 20), r.size.y), INK, rng.randf_range(6.0, 16.0))

	func _road(r: Rect2) -> void:
		# A night road in perspective under the headlights: edge lines and the centre dashes.
		var hz := r.size.y * 0.38
		var vp := Vector2(r.size.x * 0.52, hz)
		draw_colored_polygon(PackedVector2Array([vp, Vector2(r.size.x * 1.1, r.size.y), Vector2(-r.size.x * 0.1, r.size.y)]),
			Color(0.16, 0.16, 0.16))
		draw_colored_polygon(PackedVector2Array([vp, Vector2(r.size.x * 0.82, r.size.y), Vector2(r.size.x * 0.18, r.size.y)]),
			Color(0.32, 0.31, 0.28))
		draw_line(vp, Vector2(r.size.x * 0.02, r.size.y), PAPER, 4.0)
		draw_line(vp, Vector2(r.size.x * 0.98, r.size.y), PAPER, 4.0)
		# Pines crowding both verges, growing toward the frame, and the headlight pool on the tar.
		var rng := RandomNumberGenerator.new()
		rng.seed = 17 + index
		for k in 22:
			var t := pow(rng.randf(), 1.6)
			var left := k % 2 == 0
			var foot := vp.lerp(Vector2(-r.size.x * 0.1 if left else r.size.x * 1.1, r.size.y), t)
			foot.x += (-1.0 if left else 1.0) * (10.0 + rng.randf() * 40.0) * (0.3 + t)
			var h := (20.0 + 260.0 * t) * rng.randf_range(0.8, 1.2)
			var w := h * 0.28
			draw_colored_polygon(PackedVector2Array([foot + Vector2(-w, 0), foot + Vector2(w, 0), foot + Vector2(0, -h)]),
				Color(0.06, 0.06, 0.06))
			draw_line(foot + Vector2(0, -h), foot + Vector2(w * 0.6, -h * 0.4), Color(PAPER, 0.25), 1.5)
		for k in range(6, 0, -1):
			var c := Vector2(vp.x, r.size.y * 0.86)
			draw_set_transform(c, 0.0, Vector2(1.0, 0.32))
			draw_circle(Vector2.ZERO, k * r.size.x * 0.06, Color(MangaArt.HEADLAMP, 0.07))
			draw_set_transform(Vector2.ZERO)
		for k in 6:
			var a := pow(k / 6.0, 2.0)
			var b := pow((k + 0.5) / 6.0, 2.0)
			draw_line(vp.lerp(Vector2(vp.x, r.size.y), a), vp.lerp(Vector2(vp.x, r.size.y), b), PAPER, 2.0 + 10.0 * b)


## Frames, captions, bubbles and sound words, over the art (bubbles may cross the gutters).
class Overlay extends Control:
	var comic: StoryComic

	func _draw() -> void:
		for i in comic._shown:
			_frame(comic._rects[i], comic._page[i], comic._arts[i])
		if comic.waiting:
			var font := MangaType.caption()
			var a := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
			var t := "CLICK / SPACE  ▶"
			var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var at := Vector2(size.x - MARGIN - w - 14, size.y - 7)
			draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(INK, a))

	func _frame(r: Rect2, p: Dictionary, art: PanelArt) -> void:
		var a := art.modulate.a
		var off := art.position - r.position
		r.position += off
		draw_rect(r, Color(INK, a), false, 5.0)
		var dark: bool = p.get("art", "") in ["black", "rain", "wipers", "lights", "road"]
		if p.has("fx"):
			_fx(r, str(p["fx"]), dark, a)
		if p.has("cap"):
			_caption(r, comic_text(str(p["cap"])), a)
		if p.has("say"):
			_bubble(r, p, art, a)

	func comic_text(t: String) -> String:
		var d := comic.get_parent()
		return d.fill(t) if d and d.has_method("fill") else t

	func _caption(r: Rect2, text: String, a: float) -> void:
		var font := MangaType.caption()
		var fs := 19
		var w := minf(r.size.x - 28.0, 430.0)
		var ts := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, fs)
		var box := Rect2(r.position + Vector2(10, 10), Vector2(minf(w, ts.x + 26.0), ts.y + 18.0))
		draw_rect(box, Color(PAPER, a))
		draw_rect(box, Color(INK, a), false, 3.0)
		draw_multiline_string(font, box.position + Vector2(12, 9 + font.get_ascent(fs)), text,
			HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, fs, -1, Color(INK, a))

	func _bubble(r: Rect2, p: Dictionary, art: PanelArt, a: float) -> void:
		var font := MangaType.caption()
		var fs := 22
		var text := comic_text(str(p["say"]))
		var who := str(p.get("who", ""))
		var face: bool = p.get("art", "") == "face"
		var right := art.face_right() if face else false
		var free := r.size.x - art.face_size() * 0.92 - 34.0 if face else r.size.x * 0.7
		var w := clampf(free - 44.0, 140.0, 360.0)
		var ts := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, w, fs)
		var tag := who != "" and not face
		var bs := Vector2(minf(w, ts.x) + 44.0, ts.y + 34.0 + (22.0 if tag else 0.0))
		var pos: Vector2
		if face:
			# Opposite the face, high in the panel; the tail points back toward the mouth.
			# In the free side, high up; the tail reaches toward the mouth.
			var x := r.position.x + (14.0 if right else r.size.x - bs.x - 14.0)
			pos = Vector2(x, r.position.y + maxf(16.0, r.size.y * 0.1))
			if p.has("cap"):
				pos.y += 50.0
		else:
			pos = Vector2(r.get_center().x - bs.x * 0.5, r.end.y - bs.y - 22.0)
		var box := Rect2(pos, bs)
		var tail_to := Vector2(box.get_center().x + 30.0, box.end.y + 18.0)
		var base := Vector2(box.get_center().x, box.end.y - 4.0)
		if face:
			# Start on the bubble's edge nearest the face; stop short of the cheek.
			var m := r.position + art.mouth()
			base = Vector2(box.position.x + 34.0 if not right else box.end.x - 34.0, box.end.y - 4.0)
			tail_to = base + (m - base) * 0.45
			if tail_to.distance_to(base) < 22.0:
				tail_to = base + Vector2(0, 22)
		tail_to.y = minf(tail_to.y, r.end.y - 6.0)
		var tail := PackedVector2Array([base + Vector2(-17, 0), base + Vector2(17, 0), tail_to])
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(PAPER, a)
		sb.border_color = Color(INK, a)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(int(minf(bs.y, bs.x) * 0.5))
		sb.corner_detail = 12
		draw_colored_polygon(tail, Color(INK, a))
		var inner_tail := PackedVector2Array([tail[0] + Vector2(5, -2), tail[1] + Vector2(-5, -2), tail[2].lerp(base, 0.22)])
		sb.draw(get_canvas_item(), box)
		draw_colored_polygon(inner_tail, Color(PAPER, a))
		var y := box.position.y + 17.0
		if tag:
			var tw := font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var slab := Rect2(Vector2(box.get_center().x - tw * 0.5 - 8.0, y - 4.0), Vector2(tw + 16.0, 22.0))
			draw_rect(slab, Color(INK, a))
			draw_string(font, slab.position + Vector2(8, 16), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(PAPER, a))
			y += 24.0
		draw_multiline_string(font, Vector2(box.position.x + 22.0, y + font.get_ascent(fs)), text,
			HORIZONTAL_ALIGNMENT_CENTER, bs.x - 44.0, fs, -1, Color(INK, a))

	func _fx(r: Rect2, word: String, dark: bool, a: float) -> void:
		var font := MangaType.display()
		var fs := int(clampf(r.size.y * 0.3, 34.0, 84.0))
		var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while w > r.size.x * 0.8 and fs > 24:
			fs -= 4
			w = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var c := r.position + Vector2(r.size.x * 0.62 - w * 0.5, r.size.y * 0.42)
		draw_set_transform(c, -0.14, Vector2.ONE)
		var fill := MangaType.RED if not dark else PAPER
		draw_string_outline(font, Vector2.ZERO, word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(8, fs / 6), Color(INK if not dark else INK, a))
		draw_string(font, Vector2.ZERO, word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(fill, a))
		draw_set_transform(Vector2.ZERO)
