class_name SpGauge
extends Control
## One SP gauge in manga lettering: a paper bar with an ink border and offset shadow, filled in
## ink (the player) or red (the rival) from the centre of the screen outward, so a draining bar
## shrinks toward the middle like Tokyo Xtreme Racer's. Flashes while it drains.

const PAPER := MangaType.PAPER
const INK := MangaType.INK

var label := "YOU"
var fill := INK
## The bar grows leftward from its right edge (the left gauge of the pair).
var mirrored := false
var value := SpBattleRules.FULL
var draining := false
var _flash := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(280, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(value_: float, draining_: bool) -> void:
	value = value_
	draining = draining_
	queue_redraw()


func _process(delta: float) -> void:
	_flash = fmod(_flash + delta * 6.0, TAU) if draining else 0.0


func _draw() -> void:
	var font := MangaType.display()
	var bar := Rect2(0, 26, size.x, size.y - 26)
	draw_rect(Rect2(bar.position + Vector2(6, 6), bar.size), INK)
	draw_rect(bar, PAPER)
	var w := (bar.size.x - 8) * clampf(value / SpBattleRules.FULL, 0.0, 1.0)
	var x := bar.end.x - 4 - w if mirrored else bar.position.x + 4
	var colour := fill
	if draining and sin(_flash) > 0.0:
		colour = MangaType.RED if fill == INK else INK
	draw_rect(Rect2(x, bar.position.y + 4, w, bar.size.y - 8), colour)
	draw_rect(bar, INK, false, 4.0)
	# Name on the outer end, the number on the inner end, both above the bar.
	var name_size := 22
	var name_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var num := "%d" % ceili(value)
	var num_w := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var name_x := 0.0 if mirrored else size.x - name_w
	var num_x := size.x - num_w if mirrored else 0.0
	for pair in [[label, name_x], [num, num_x]]:
		draw_string_outline(font, Vector2(pair[1], 20), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, 8, INK)
		draw_string(font, Vector2(pair[1], 20), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, PAPER)
