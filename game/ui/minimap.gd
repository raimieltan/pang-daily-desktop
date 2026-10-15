class_name Minimap
extends Control
## Manga course map: a paper panel with a thick ink border and hard drop shadow, the road drawn as
## an ink stroke with a paper core, start tick and checkered finish flag, the player as a red
## arrow and rivals as ink dots. North-up unless the course is long and thin, in which case the
## whole map turns once so its longest axis runs up the panel. Sits top-left.

const PAPER := MangaType.PAPER
const INK := MangaType.INK
const RED := MangaType.RED

const SHADOW := Vector2(8, 8)
const BORDER := 6.0
const PADDING := 20.0
const CAPTION_ROOM := 16.0
const DECIMATE := 4
const ROAD_INK := 9.0
const ROAD_PAPER := 3.5
## Rotate only when that fits the course at least this much larger than north-up.
const ROTATE_GAIN := 1.2

var track: TrackData:
	set(value):
		track = value
		_build()
var player: Node3D
var rivals: Array[Node3D] = []

var _line := PackedVector2Array()
var _angle := 0.0
var _origin := Vector2.ZERO
var _scale := 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(240, 240)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()


func _process(_delta: float) -> void:
	queue_redraw()


func _panel() -> Rect2:
	return Rect2(Vector2.ZERO, size - SHADOW)


## Drawable area: the panel less padding, with extra headroom under the caption tab.
func _room() -> Rect2:
	var room := _panel().grow(-PADDING)
	room.position.y += CAPTION_ROOM
	room.size.y -= CAPTION_ROOM
	return room


func _build() -> void:
	_line.clear()
	if track == null or track.points.size() < 2:
		return
	var raw := PackedVector2Array()
	for i in range(0, track.points.size(), DECIMATE):
		raw.append(_flat(track.points[i]))
	raw.append(_flat(track.points[track.points.size() - 1]))
	_angle = _best_angle(raw)
	_fit(raw)
	for p in raw:
		_line.append(_to_map(p))


## World x/z on the page plane: +X right, -Z up.
static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## North-up, or the principal axis turned vertical when that fills the panel noticeably better.
## A rotated map keeps the start below the finish so the run climbs the page.
func _best_angle(raw: PackedVector2Array) -> float:
	var axis := _principal_angle(raw)
	var turned := PI * 0.5 - axis
	if _fit_scale(raw, turned) < _fit_scale(raw, 0.0) * ROTATE_GAIN:
		return 0.0
	if raw[0].rotated(turned).y < raw[raw.size() - 1].rotated(turned).y:
		turned += PI
	return turned


static func _principal_angle(raw: PackedVector2Array) -> float:
	var mean := Vector2.ZERO
	for p in raw:
		mean += p
	mean /= raw.size()
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	for p in raw:
		var d := p - mean
		sxx += d.x * d.x
		syy += d.y * d.y
		sxy += d.x * d.y
	return 0.5 * atan2(2.0 * sxy, sxx - syy)


static func _bounds(raw: PackedVector2Array, angle: float) -> Rect2:
	var box := Rect2(raw[0].rotated(angle), Vector2.ZERO)
	for p in raw:
		box = box.expand(p.rotated(angle))
	return box


func _fit_scale(raw: PackedVector2Array, angle: float) -> float:
	var box := _bounds(raw, angle)
	var room := _room().size
	return minf(room.x / maxf(box.size.x, 1.0), room.y / maxf(box.size.y, 1.0))


func _fit(raw: PackedVector2Array) -> void:
	var box := _bounds(raw, _angle)
	_scale = _fit_scale(raw, _angle)
	_origin = _room().get_center() - box.get_center() * _scale


func _to_map(p: Vector2) -> Vector2:
	return _origin + p.rotated(_angle) * _scale


func _world_to_map(p: Vector3) -> Vector2:
	return _to_map(_flat(p))


func _draw() -> void:
	var panel := _panel()
	draw_rect(Rect2(panel.position + SHADOW, panel.size), INK)
	draw_rect(panel, PAPER)
	if not _line.is_empty():
		_draw_road()
		_draw_marks()
		_draw_cars()
	draw_rect(panel.grow(-BORDER * 0.5), INK, false, BORDER)
	_draw_caption(panel)


func _draw_road() -> void:
	draw_polyline(_line, INK, ROAD_INK, true)
	draw_circle(_line[0], ROAD_INK * 0.5, INK)
	draw_circle(_line[_line.size() - 1], ROAD_INK * 0.5, INK)
	draw_polyline(_line, PAPER, ROAD_PAPER, true)


func _draw_marks() -> void:
	var finish := track.finish_distance if track.finish_distance > 0.0 else track.length()
	_draw_start(track.index_at(track.start_distance))
	_draw_flag(track.index_at(finish))


func _road_dir(i: int) -> Vector2:
	var f := track.forwards[i] if i < track.forwards.size() else Vector3.FORWARD
	var d := _flat(f).rotated(_angle)
	return d.normalized() if d.length_squared() > 0.0 else Vector2.UP


## A bold ink bar across the road.
func _draw_start(i: int) -> void:
	var at := _world_to_map(track.points[i])
	var across := _road_dir(i).orthogonal() * 9.0
	draw_line(at - across, at + across, INK, 5.0)


## A small checkered flag planted beside the finish; it hangs below the road near the top edge.
func _draw_flag(i: int) -> void:
	var at := _world_to_map(track.points[i])
	var across := _road_dir(i).orthogonal() * 9.0
	draw_line(at - across, at + across, INK, 5.0)
	var cell := 4.0
	var foot := at + Vector2(6, 0)
	var top := foot + Vector2(0, -24)
	var origin := top + Vector2(1.0, 0.0)
	if top.y < _room().position.y:
		top = foot + Vector2(0, 24)
		origin = top + Vector2(1.0, -cell * 3)
	draw_line(foot, top, INK, 2.5)
	draw_rect(Rect2(origin, Vector2(cell * 4, cell * 3)), PAPER)
	for y in 3:
		for x in 4:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2.ONE * cell), INK)
	draw_rect(Rect2(origin, Vector2(cell * 4, cell * 3)), INK, false, 1.5)


func _draw_cars() -> void:
	for rival in rivals:
		if is_instance_valid(rival):
			var at := _world_to_map(rival.global_position)
			draw_circle(at, 6.0, PAPER)
			draw_circle(at, 4.5, INK)
	if is_instance_valid(player):
		_draw_arrow(_world_to_map(player.global_position), _heading(player))


func _heading(node: Node3D) -> Vector2:
	var d := _flat(-node.global_basis.z).rotated(_angle)
	return d.normalized() if d.length_squared() > 0.0 else Vector2.UP


## Red arrowhead with an ink outline and its own small hard shadow.
func _draw_arrow(at: Vector2, dir: Vector2) -> void:
	var side := dir.orthogonal()
	var tri := PackedVector2Array([at + dir * 11.0, at - dir * 7.0 + side * 7.5, at - dir * 3.0, at - dir * 7.0 - side * 7.5])
	var shadow := tri.duplicate()
	for i in shadow.size():
		shadow[i] += Vector2(3, 3)
	draw_colored_polygon(shadow, INK)
	draw_colored_polygon(tri, RED)
	tri.append(tri[0])
	draw_polyline(tri, INK, 2.5, true)


## "MAP" lettered on an ink tab hanging from the top border.
func _draw_caption(panel: Rect2) -> void:
	var font := MangaType.caption()
	var font_size := 22
	var text_size := font.get_string_size("MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var tab := Rect2(panel.position + Vector2(BORDER + 4.0, 0.0), text_size + Vector2(16, 6))
	draw_rect(tab, INK)
	var base := tab.position + Vector2(8, 3 + font.get_ascent(font_size))
	draw_string(font, base, "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, PAPER)
