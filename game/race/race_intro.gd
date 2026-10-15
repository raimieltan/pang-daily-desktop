class_name RaceIntro
extends Node
## The pre-race cinematic, cut like a manga spread: letterbox ink bars, a crane shot of the grid
## with the stage caption, a close shot and slanted name card per driver, ink wipes between shots,
## then "READY?". Any key or click skips. Emits `finished` and hands the view back.

signal finished

const INK := MangaType.INK
const PAPER := MangaType.PAPER
const RED := MangaType.RED
const BAR := 0.11
const ESTABLISH_SECONDS := 2.6
const CARD_SECONDS := 1.7

var camera: Camera3D
## Play HUD layers (gauges, switches) hidden while the intro owns the screen.
var hud_nodes: Array = []
var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _wipe: ColorRect
var _caption: VBoxContainer
var _card: NameCard
var _lines: SpeedLines
var _ready_label: Label
var _playing := false
var _skip := false
var _from := Transform3D()
var _to := Transform3D()
var _shot_time := 0.0
var _shot_length := 1.0
var _return_camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 52.0
	add_child(camera)
	_layer = CanvasLayer.new()
	_layer.layer = 15
	_layer.visible = false
	add_child(_layer)
	_lines = SpeedLines.new()
	_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_lines)
	_top = _bar(Control.PRESET_TOP_WIDE)
	_bottom = _bar(Control.PRESET_BOTTOM_WIDE)
	_caption = VBoxContainer.new()
	_caption.position = Vector2(48, 0)
	_layer.add_child(_caption)
	_card = NameCard.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_card)
	_ready_label = MangaType.label("", 150)
	_ready_label.set_anchors_preset(Control.PRESET_CENTER)
	_ready_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ready_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(_ready_label)
	_wipe = ColorRect.new()
	_wipe.color = INK
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_wipe)


func _bar(preset: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = INK
	r.set_anchors_preset(preset)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(r)
	return r


## cast: [{ "node": Node3D, "name": String, "car": String }], player last.
func play(track: TrackData, cast: Array, title: String, subtitle: String) -> void:
	_playing = true
	_skip = false
	_return_camera = get_viewport().get_camera_3d()
	if _return_camera:
		# Same page look: the manga post pass lives on the camera's compositor.
		camera.compositor = _return_camera.compositor
		camera.attributes = _return_camera.attributes
		camera.far = _return_camera.far
	camera.current = true
	_layer.visible = true
	for n in hud_nodes:
		n.visible = false
	_ready_label.text = ""
	_card.clear()
	var h := get_viewport().get_visible_rect().size.y
	_top.size.y = h * BAR
	_bottom.size.y = h * BAR
	_bottom.position.y = h * (1.0 - BAR)
	_wipe.size = Vector2.ZERO

	await _establish(track, cast, title, subtitle)
	for member in cast:
		if _skip:
			break
		await _ink_wipe()
		await _close_up(member)
	if not _skip:
		await _ink_wipe()
		_card.clear()
		_caption.visible = false
		var player: Node3D = cast[-1]["node"]
		_set_shot(_chase(player, 9.0, 3.2), _chase(player, 6.5, 2.2), 1.2)
		_ready_label.text = "READY?"
		_pop(_ready_label)
		await _wait(1.2)
	_finish()


func skip() -> void:
	if _playing:
		_skip = true


func _finish() -> void:
	if not _playing:
		return
	_playing = false
	_layer.visible = false
	_lines.strength = 0.0
	for n in hud_nodes:
		n.visible = true
	if _return_camera:
		_return_camera.current = true
	finished.emit()


func _establish(track: TrackData, cast: Array, title: String, subtitle: String) -> void:
	var line := track.pose_at(track.start_distance)
	var i := track.index_at(track.start_distance)
	var fwd := track.forwards[i]
	var grid_center: Vector3 = (cast[0]["node"] as Node3D).global_position
	for m in cast:
		grid_center = grid_center.lerp((m["node"] as Node3D).global_position, 0.5)
	var eye_a: Vector3 = line["position"] + fwd * 14.0 + Vector3.UP * 9.0 + track.rights[i] * 6.0
	var eye_b: Vector3 = line["position"] + fwd * 8.0 + Vector3.UP * 4.0 + track.rights[i] * 4.0
	_set_shot(Transform3D().looking_at(grid_center - eye_a, Vector3.UP).translated(eye_a),
		Transform3D().looking_at(grid_center - eye_b, Vector3.UP).translated(eye_b), ESTABLISH_SECONDS)
	_show_caption(title, subtitle)
	await _wait(ESTABLISH_SECONDS)


func _close_up(member: Dictionary) -> void:
	var car: Node3D = member["node"]
	var f := -car.global_basis.z
	var r := car.global_basis.x
	var look := car.global_position + Vector3.UP * 0.6
	# The side with open air: a rail or rock face beside the grid would fill the shot.
	var side := 1.0
	if _blocked(look, car.global_position + f * 2.2 + r * 2.9 + Vector3.UP * 0.7):
		side = -1.0
	var eye_a := car.global_position + f * 3.4 + r * side * 1.6 + Vector3.UP * 0.45
	var eye_b := car.global_position + f * 2.2 + r * side * 2.9 + Vector3.UP * 0.7
	if _blocked(look, eye_b):
		eye_a += Vector3.UP * 2.0 - r * side * 0.8
		eye_b += Vector3.UP * 2.4 - r * side * 1.2
	_set_shot(Transform3D().looking_at(look - eye_a, Vector3.UP).translated(eye_a),
		Transform3D().looking_at(look - eye_b, Vector3.UP).translated(eye_b), CARD_SECONDS)
	_caption.visible = false
	_card.show_card(member["name"], member["car"], side < 0.0, member["name"] == "YOU")
	_lines.strength = 1.0
	await _wait(CARD_SECONDS)
	_lines.strength = 0.0


func _blocked(from: Vector3, to: Vector3) -> bool:
	var space := camera.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to + (to - from).normalized() * 0.5, CarBody.STATIC_LAYER)
	return not space.intersect_ray(q).is_empty()


func _chase(car: Node3D, back: float, up: float) -> Transform3D:
	var eye := car.global_position + car.global_basis.z * back + Vector3.UP * up
	return Transform3D().looking_at(car.global_position + Vector3.UP * 0.8 - eye, Vector3.UP).translated(eye)


func _show_caption(title: String, subtitle: String) -> void:
	for c in _caption.get_children():
		c.queue_free()
	_caption.visible = true
	var h := get_viewport().get_visible_rect().size.y
	_caption.position.y = h * BAR + 28.0
	var t := MangaType.label(title, 86)
	_caption.add_child(t)
	var s := Label.new()
	s.text = subtitle
	MangaType.ink(s, 32, MangaType.caption())
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = INK
	style.set_border_width_all(4)
	style.set_content_margin_all(10)
	style.shadow_color = INK
	style.shadow_size = 1
	style.shadow_offset = Vector2(6, 6)
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(s)
	_caption.add_child(box)
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.25)


## An ink slash crosses the screen, the shot changes behind it, then it clears.
func _ink_wipe() -> void:
	var size := get_viewport().get_visible_rect().size
	_wipe.size = Vector2(size.x * 1.4, size.y)
	_wipe.position = Vector2(-size.x * 1.45, 0)
	var t := create_tween()
	t.tween_property(_wipe, "position:x", -size.x * 0.2, 0.14)
	await t.finished
	var out := create_tween()
	out.tween_property(_wipe, "position:x", size.x * 1.05, 0.16)


func _pop(label: Label) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * 1.6
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _set_shot(from: Transform3D, to: Transform3D, seconds: float) -> void:
	_from = from
	_to = to
	_shot_time = 0.0
	_shot_length = seconds
	camera.global_transform = from


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()


func _process(delta: float) -> void:
	if not _playing:
		return
	_shot_time += delta
	var k := clampf(_shot_time / _shot_length, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	camera.global_transform = _from.interpolate_with(_to, k)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo and not event.is_action("pause")
	var click: bool = event is InputEventMouseButton and event.pressed
	var pad: bool = event is InputEventJoypadButton and event.pressed
	if key or click or pad:
		get_viewport().set_input_as_handled()
		skip()


## A slanted ink banner with the driver's name, sliding in from one side.
class NameCard extends Control:
	var _name := ""
	var _car := ""
	var _left := true
	var _player := false
	var _t := 1.0

	func clear() -> void:
		_name = ""
		queue_redraw()

	func show_card(driver: String, car: String, from_left: bool, player: bool) -> void:
		_name = driver
		_car = car
		_left = from_left
		_player = player
		_t = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if _name != "" and _t < 1.0:
			_t = minf(1.0, _t + delta * 5.0)
			queue_redraw()

	func _draw() -> void:
		if _name == "":
			return
		var s := size
		var ease := 1.0 - pow(1.0 - _t, 3.0)
		var w := s.x * 0.62
		var h := 150.0
		var y := s.y * 0.62
		var x0 := -w + ease * (w + 40.0) if _left else s.x - ease * (w + 40.0)
		var slant := 60.0
		var band := PackedVector2Array([Vector2(x0, y), Vector2(x0 + w + slant, y), Vector2(x0 + w, y + h), Vector2(x0 - slant, y + h)])
		draw_colored_polygon(_offset(band, Vector2(10, 10)), MangaType.INK)
		draw_colored_polygon(band, MangaType.RED if _player else MangaType.INK)
		draw_polyline(band + PackedVector2Array([band[0]]), MangaType.PAPER, 4.0)
		var font := MangaType.display()
		var cap := MangaType.caption()
		var tag := "PLAYER" if _player else "RIVAL"
		draw_string(cap, Vector2(x0 + 34, y + 38), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, MangaType.PAPER)
		draw_string_outline(font, Vector2(x0 + 30, y + 104), _name, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, 10, MangaType.INK)
		draw_string(font, Vector2(x0 + 30, y + 104), _name, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, MangaType.PAPER)
		draw_string(cap, Vector2(x0 + 36, y + 138), _car, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, MangaType.PAPER)

	func _offset(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for v in p:
			out.append(v + d)
		return out


## Radial ink speed lines toward the centre, flickering while a close-up holds.
class SpeedLines extends Control:
	var strength := 0.0:
		set(v):
			strength = v
			queue_redraw()
	var _seed := 0

	func _process(_delta: float) -> void:
		if strength > 0.0:
			_seed += 1
			if _seed % 3 == 0:
				queue_redraw()

	func _draw() -> void:
		if strength <= 0.0:
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed / 3
		var c := size / 2.0
		var r := size.length() / 2.0
		for i in 70:
			var a := rng.randf() * TAU
			var dir := Vector2(cos(a), sin(a))
			var inner := r * rng.randf_range(0.55, 0.8)
			var w := rng.randf_range(2.0, 7.0) * strength
			var p0 := c + dir * r
			var p1 := c + dir * inner
			var n := Vector2(-dir.y, dir.x) * w
			draw_colored_polygon(PackedVector2Array([p0 + n, p0 - n, p1]), MangaType.INK)
