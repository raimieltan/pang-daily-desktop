class_name EvidenceBoard
extends CanvasLayer
## The investigation page: evidence cards across the top (text, Jolo's edit timeline, the clip's
## traces with their seams, the logger, the map of 8A, sector sheets), then a question with
## options under it. Every card draws from what the player actually drove (StoryMode.record);
## the answer has to come from something on the page. Wrong picks get a nudge, never a fail.

signal answered

## Shared drawing context: { "ghost": GhostLine, "track": TrackData, "record", "results", "tokens" }.
var context := {}
var dialogue: StoryDialogue
var _root: Control
var _cards: HBoxContainer
var _question: Label
var _options: GridContainer
var _confirm: Button
var _picked := {}
var _beat := {}


func _ready() -> void:
	layer = 14
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var wash := ColorRect.new()
	wash.color = Color(MangaType.PAPER, 0.9)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(wash)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 40
	column.offset_right = -40
	column.offset_top = 30
	column.offset_bottom = -20
	column.add_theme_constant_override("separation", 12)
	_root.add_child(column)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 26)
	column.add_child(_cards)
	_question = Label.new()
	MangaType.ink(_question, 26)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_question)
	_options = GridContainer.new()
	_options.add_theme_constant_override("h_separation", 16)
	_options.add_theme_constant_override("v_separation", 2)
	_options.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_options)
	_root.visible = false


## Show the beat's cards; with a question, wait for a right answer; without, wait for a press.
func examine(beat: Dictionary) -> void:
	_beat = beat
	for c in _cards.get_children():
		c.queue_free()
	for c in _options.get_children():
		c.queue_free()
	_picked.clear()
	var cards: Array = beat.get("cards", beat.get("after_cards", []))
	var asked: bool = beat.get("question", "") != ""
	# The page is 1072 px wide inside its margins; cards share it, shorter when a question follows.
	var width := (1040.0 - 26.0 * (cards.size() - 1)) / cards.size()
	var height := 250.0 if asked else 440.0
	for spec in cards:
		_cards.add_child(_make_card(spec, Vector2(width, height)))
	_root.visible = true
	var question: String = beat.get("question", "")
	_question.text = question
	if question == "":
		var go := _option_button("CONTINUE", -1)
		go.pressed.connect(func(): answered.emit())
		go.grab_focus.call_deferred()
		if StoryDialogue.auto_advance > 0.0:
			get_tree().create_timer(StoryDialogue.auto_advance * 2.0).timeout.connect(func(): answered.emit())
		await answered
		_root.visible = false
		return
	var options: Array = beat["options"]
	_options.columns = 2 if options.size() > 4 else 1
	for i in options.size():
		var b := _option_button("%s.  %s" % ["ABCDEFGH"[i], options[i]], i)
		b.toggle_mode = _pick_count() > 1
		b.pressed.connect(_on_option.bind(i, b))
	if _pick_count() > 1:
		_confirm = _option_button("CONFIRM  (PICK %d)" % _pick_count(), -1)
		_confirm.pressed.connect(_check)
	(_options.get_child(0) as Button).grab_focus.call_deferred()
	if StoryDialogue.auto_advance > 0.0:
		_auto_answer.call_deferred()
	await answered
	_root.visible = false


func _pick_count() -> int:
	return int(_beat.get("pick", 1))


func _auto_answer() -> void:
	await get_tree().create_timer(StoryDialogue.auto_advance).timeout
	var answer: Array = _beat["answer"]
	for k in _pick_count():
		_picked[int(answer[k])] = true
	_check()


func _on_option(i: int, b: Button) -> void:
	if _pick_count() == 1:
		_picked = { i: true }
		_check()
		return
	if b.button_pressed:
		_picked[i] = true
	else:
		_picked.erase(i)


func _check() -> void:
	var answer: Array = _beat["answer"]
	var ok := _picked.size() == _pick_count()
	for i in _picked:
		if not (i in answer):
			ok = false
	if ok:
		dialogue.sfx("shutter")
		answered.emit()
		return
	_root.visible = false
	var nudge: Array = _beat.get("wrong", ["RUEL", "Look again."])
	await dialogue.play([nudge])
	_root.visible = true
	_picked.clear()
	for c in _options.get_children():
		(c as Button).button_pressed = false
	(_options.get_child(0) as Button).grab_focus.call_deferred()


func _option_button(text: String, _i: int) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.x = 520 if _options.columns == 2 else 900
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MangaType.ink(b, 19, MangaType.caption())
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(MangaType.PAPER, 0.0)
	plain.set_content_margin_all(4)
	plain.content_margin_left = 14
	var lit := StyleBoxFlat.new()
	lit.bg_color = MangaType.INK
	lit.set_content_margin_all(4)
	lit.content_margin_left = 14
	var marked := StyleBoxFlat.new()
	marked.bg_color = MangaType.RED
	marked.set_content_margin_all(4)
	marked.content_margin_left = 14
	b.add_theme_stylebox_override("normal", plain)
	for state in ["hover", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(state, lit)
	b.add_theme_stylebox_override("pressed", marked)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, MangaType.PAPER)
	b.mouse_entered.connect(b.grab_focus)
	_options.add_child(b)
	return b


func _make_card(spec: Dictionary, area: Vector2) -> Control:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = MangaType.PAPER
	box.border_color = MangaType.INK
	box.set_border_width_all(4)
	box.set_content_margin_all(12)
	box.shadow_color = MangaType.INK
	box.shadow_size = 1
	box.shadow_offset = Vector2(6, 6)
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size = area
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var title := Label.new()
	title.text = spec.get("title", "")
	MangaType.ink(title, 20, MangaType.caption())
	title.add_theme_color_override("font_color", MangaType.PAPER)
	var slab := StyleBoxFlat.new()
	slab.bg_color = MangaType.INK
	slab.content_margin_left = 10
	slab.content_margin_right = 10
	title.add_theme_stylebox_override("normal", slab)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(title)
	var kind: String = spec.get("kind", "text")
	if kind == "text":
		var body := Label.new()
		body.text = String(spec.get("body", "")).format(context.get("tokens", {}))
		MangaType.ink(body, 18, MangaType.caption())
		body.custom_minimum_size.x = area.x - 30.0
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(body)
		return card
	var plot := Plot.new()
	plot.kind = kind
	plot.context = context
	plot.note = spec.get("body", "")
	plot.custom_minimum_size = area - Vector2(26, 54)
	column.add_child(plot)
	return card


## A drawn evidence card: traces, timelines, maps and sheets, in ink on paper. Laid out relative to
## its size, so a card fits beside others or alone on the page.
class Plot extends Control:
	var kind := ""
	var context := {}
	var note := ""
	var _t := 0.0
	var _font: Font = MangaType.caption()

	func _process(delta: float) -> void:
		if kind in ["clip", "match", "logger"]:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), MangaType.PAPER)
		match kind:
			"edit": _draw_edit()
			"clip": _draw_clip()
			"match": _draw_match()
			"logger": _draw_logger()
			"map": _draw_map()
			"board": _draw_board()
			"notes": _draw_notes()
			"trials": _draw_trials()

	func _text(at: Vector2, text: String, size_px := 17, color := MangaType.INK) -> void:
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

	func _ghost() -> GhostLine:
		return context.get("ghost", GhostLine.new())

	func _no_footage() -> bool:
		if _ghost().valid():
			return false
		_text(Vector2(14, 30), "(no footage on this save)")
		return true

	## Jolo's edit: the source passes as rows, the cut as the bottom row, sector by sector.
	func _draw_edit() -> void:
		if _no_footage():
			return
		var g := _ghost()
		var left := size.x * 0.24
		var w := size.x - left - 10.0
		var rows := g.labels.size() + 1
		var row := (size.y - 70.0) / rows
		for i in rows:
			var y := 6.0 + i * row
			var cut := i == g.labels.size()
			var name := "GHOST_LINE_COMPOSITE" if cut else "PASS %s  %s" % ["ABC"[i] if i < 3 else str(i), g.labels[i].get_slice("·", 2).strip_edges()]
			_text(Vector2(6, y + row * 0.6), name, 15, MangaType.RED if cut else MangaType.INK)
			for k in 4:
				var sw := w / 4.0
				var on := cut or g.picks[k] == i
				var fill := MangaType.RED if cut else (MangaType.INK if on else Color(MangaType.INK, 0.12))
				draw_rect(Rect2(left + k * sw + 2, y + 3, sw - 4, row - 6), fill)
				var label := "S%d ← %s" % [k + 1, "ABC"[g.picks[k]] if g.picks[k] < 3 else str(g.picks[k])] if cut else "S%d  %.2f" % [k + 1, g.source_sectors[i][k]]
				_text(Vector2(left + k * sw + 8, y + row * 0.6), label, 15, MangaType.PAPER if on else MangaType.INK)
		_text(Vector2(left, size.y - 38), "TOTAL  " + TimeAttackRun.format_time(g.time), 20)
		_text(Vector2(left, size.y - 10), note, 18, MangaType.RED)

	## The composite's speed over time with a playhead; seams appear once the playhead has crossed
	## them, and the logger clock (time into the source pass) jumps there.
	func _draw_clip() -> void:
		if _no_footage():
			return
		var g := _ghost()
		var r := Rect2(60, 8, size.x - 72, size.y - 70)
		var t := fmod(_t * 6.0, g.time + 3.0)
		_trace(g, GhostLine.SPEED, r, 0.0, 45.0, MangaType.INK, 2.5)
		_axes(r, "SPEED", g.time)
		var head := r.position.x + clampf(t / g.time, 0.0, 1.0) * r.size.x
		draw_line(Vector2(head, r.position.y), Vector2(head, r.end.y), MangaType.RED, 2.0)
		for seam in g.seams:
			if t >= seam:
				var x := r.position.x + seam / g.time * r.size.x
				draw_dashed_line(Vector2(x, r.position.y), Vector2(x, r.end.y), MangaType.RED, 2.0, 6.0)
				_text(Vector2(x + 4, r.position.y + 16), "JOIN?", 15, MangaType.RED)
		var i := clampi(int(t * GhostLine.HZ), 0, g.frame_count() - 1)
		var past_join := g.seams.size() > 0 and t >= g.seams[0]
		_text(Vector2(60, size.y - 36), "CLIP  %s      LOGGER CLOCK  %s" % [TimeAttackRun.format_time(minf(t, g.time)),
			TimeAttackRun.format_time(g.clock[i])], 18)
		_text(Vector2(60, size.y - 10), "FROM: " + g.labels[g.source[i]], 15, MangaType.RED if past_join else MangaType.INK)

	## Steering of the circulating clip over the raw source clip, through the first sector.
	func _draw_match() -> void:
		if _no_footage():
			return
		var g := _ghost()
		var r := Rect2(60, 8, size.x - 72, size.y - 44)
		var span := g.splits[0]
		var raw: PackedFloat32Array = context.get("raw0", PackedFloat32Array())
		var shown := clampf(_t * 4.0, 0.0, span)
		_trace_range(g.frames, GhostLine.STEER, r, -1.0, 1.0, span, shown, MangaType.INK, 6.0)
		if raw.size() > 0:
			_trace_range(raw, GhostLine.STEER, r, -1.0, 1.0, span, shown, MangaType.RED, 2.0)
		_axes(r, "STEER", span)
		_text(Vector2(60, size.y - 10), "INK: GHOST LINE (CIRCULATING)     RED: RAW CLIP · %s" % g.labels[g.picks[0]].get_slice("·", 1).strip_edges(), 16)

	## The night run from 160 m before 8A to the end: speed, brake and steering, the dry practice
	## speed dashed, 8A marked, and where the camera file breaks off.
	func _draw_logger() -> void:
		var crash: PackedFloat32Array = context.get("crash", PackedFloat32Array())
		var n := crash.size() / GhostLine.STRIDE
		if n < 2:
			_text(Vector2(14, 30), "(logger unreadable on this save)")
			return
		var from := maxi(0, n - int(12 * GhostLine.HZ))
		for i in range(from, n):
			if crash[i * GhostLine.STRIDE + GhostLine.DISTANCE] >= StoryCourse.fatal_entry() - 160.0:
				from = maxi(0, i - 4)
				break
		var part := crash.slice(from * GhostLine.STRIDE)
		var span := (n - from) / GhostLine.HZ
		var shown := clampf(_t * 6.0, 0.0, span)
		var left := 70.0
		var h := (size.y - 30.0) / 3.0
		var rows := [["SPEED", GhostLine.SPEED, 5.0, 32.0], ["BRAKE", GhostLine.BRAKE, 0.0, 1.0], ["STEER", GhostLine.STEER, -1.0, 1.0]]
		for k in rows.size():
			var r := Rect2(left, 4 + k * h, size.x - left - 8, h - 8)
			draw_rect(r, MangaType.INK, false, 1.0)
			_text(Vector2(4, r.position.y + 18), rows[k][0], 15)
			_trace_range(part, rows[k][1], r, rows[k][2], rows[k][3], span, shown, MangaType.INK, 2.5)
			if k == 0:
				_dry_speed(part, context.get("dry", PackedFloat32Array()), r, span, shown)
		var w := size.x - left - 8
		var entry := StoryCourse.fatal_entry()
		for i in range(part.size() / GhostLine.STRIDE):
			if part[i * GhostLine.STRIDE + GhostLine.DISTANCE] >= entry:
				var x := left + (i / GhostLine.HZ) / span * w
				draw_line(Vector2(x, 4), Vector2(x, size.y - 26), MangaType.RED, 2.0)
				_text(Vector2(x - 26, 20), "8A", 18, MangaType.RED)
				break
		var cut: float = context.get("camera_cut", -1.0)
		if cut >= 0.0:
			var cx := left + clampf((cut - from / GhostLine.HZ) / span, 0.0, 1.0) * w
			draw_dashed_line(Vector2(cx, 4), Vector2(cx, size.y - 26), MangaType.INK, 2.0, 5.0)
			_text(Vector2(cx - 130, 38), "CAMERA FILE ENDS", 15)
		_text(Vector2(left, size.y - 6), "INK: THE NIGHT RUN (WET, WORN FRONTS)     DASHED: DRY PRACTICE, SAME METRES", 15)

	func _dry_speed(part: PackedFloat32Array, dry: PackedFloat32Array, r: Rect2, span: float, shown: float) -> void:
		var dn := dry.size() / GhostLine.STRIDE
		if dn < 2:
			return
		var j := 0
		var prev := Vector2.INF
		for i in range(part.size() / GhostLine.STRIDE):
			var t := i / GhostLine.HZ
			if t > shown:
				break
			var d := part[i * GhostLine.STRIDE + GhostLine.DISTANCE]
			while j < dn - 1 and dry[j * GhostLine.STRIDE + GhostLine.DISTANCE] < d:
				j += 1
			var v := dry[j * GhostLine.STRIDE + GhostLine.SPEED]
			var p := Vector2(r.position.x + t / span * r.size.x, r.end.y - clampf((v - 5.0) / 27.0, 0.0, 1.0) * r.size.y)
			if prev != Vector2.INF and i % 2 == 0:
				draw_line(prev, p, MangaType.INK, 1.5)
			prev = p

	## Pass 1 from above: the road, 8A in red, the lower switchback grey, and the line of sight.
	func _draw_map() -> void:
		var track: TrackData = context.get("track")
		if track == null:
			return
		var entry := StoryCourse.fatal_entry()
		var lower := StoryCourse.lower_leg()
		var from := int(entry - 220.0)
		var to := int(lower.y + 120.0)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for i in range(from, to):
			var p := track.points[i]
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		var pad := 24.0
		var s := minf((size.x - 2 * pad) / (hi.x - lo.x), (size.y - 2 * pad) / (hi.y - lo.y))
		var to_px := func(p: Vector3) -> Vector2: return Vector2(pad + (p.x - lo.x) * s, pad + (p.z - lo.y) * s)
		var prev: Vector2 = to_px.call(track.points[from])
		for i in range(from + 2, to, 2):
			var q: Vector2 = to_px.call(track.points[i])
			var d := float(i)
			var color := MangaType.INK
			var width := 5.0
			if d >= entry and d <= StoryCourse.fatal_exit():
				color = MangaType.RED
				width = 8.0
			elif d >= lower.x and d <= lower.y:
				color = Color(MangaType.INK, 0.4)
			draw_line(prev, q, color, width)
			prev = q
		var bend: Vector2 = to_px.call(track.points[int(entry - 40.0)])
		var low: Vector2 = to_px.call(track.points[int((lower.x + lower.y) * 0.5)])
		draw_dashed_line(bend, low, MangaType.RED, 2.0, 7.0)
		draw_circle(bend, 6.0, MangaType.RED)
		draw_circle(low, 6.0, MangaType.INK)
		_text(bend + Vector2(10, -8), "YOU, INTO 8A", 16, MangaType.RED)
		_text(low + Vector2(10, 18), "THE LIGHTS: LOWER ROAD", 16)

	func _draw_board() -> void:
		_table(["DRIVER", "S1", "S2", "S3", "S4", "TOTAL"], context.get("board", []), [0, 2, 3, 4, 5, 6])
		if _ghost().valid():
			_text(Vector2(14, size.y - 8), "Small print under the board, before the next slide: COMBINED BEST SECTORS", 15, Color(MangaType.INK, 0.55))

	func _draw_notes() -> void:
		var rows: Array = context.get("notes", [])
		_table(["SECTOR", "GHOST", "YOU", "GAP"], rows, [0, 3, 5, 7])
		var g := _ghost()
		var y := 64.0 + (rows.size() + 1) * 32.0
		for seam in g.seams:
			var i := int(seam * GhostLine.HZ)
			_text(Vector2(14, y), "Clip %s: logger clock %s → %s. The picture never cuts." % [TimeAttackRun.format_time(seam),
				TimeAttackRun.format_time(g.clock[maxi(0, i - 1)]), TimeAttackRun.format_time(g.clock[mini(i, g.frame_count() - 1)])], 17, MangaType.RED)
			y += 26.0

	func _draw_trials() -> void:
		_table(["", "TIME"], context.get("trials", []), [0, 6])

	func _table(head: Array, rows: Array, cols: Array) -> void:
		var cw := size.x / 8.0
		for c in head.size():
			_text(Vector2(14 + cols[c] * cw, 26), head[c], 18, MangaType.RED)
		draw_line(Vector2(8, 36), Vector2(size.x - 8, 36), MangaType.INK, 2.0)
		for r in rows.size():
			var row: Array = rows[r]
			for c in mini(row.size(), cols.size()):
				_text(Vector2(14 + cols[c] * cw, 64 + r * 32), str(row[c]), 18)

	func _axes(r: Rect2, label: String, span: float) -> void:
		draw_rect(r, MangaType.INK, false, 2.0)
		_text(Vector2(r.position.x - 56, r.position.y + 16), label, 14)
		_text(Vector2(r.end.x - 50, r.end.y + 18), "%.0f s" % span, 14)

	func _trace(g: GhostLine, field: int, r: Rect2, lo: float, hi: float, color: Color, width: float) -> void:
		_trace_range(g.frames, field, r, lo, hi, g.time, g.time, color, width)

	func _trace_range(data: PackedFloat32Array, field: int, r: Rect2, lo: float, hi: float, span: float, shown: float, color: Color, width: float) -> void:
		var n := data.size() / GhostLine.STRIDE
		var pts := PackedVector2Array()
		for i in n:
			var t := i / GhostLine.HZ
			if t > shown or t > span:
				break
			var v := clampf((data[i * GhostLine.STRIDE + field] - lo) / (hi - lo), 0.0, 1.0)
			pts.append(Vector2(r.position.x + t / span * r.size.x, r.end.y - v * r.size.y))
		if pts.size() >= 2:
			draw_polyline(pts, color, width)
