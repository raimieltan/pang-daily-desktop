extends Node
## Story mode's paper stage: rooms the game does not build (a rented room, Jolo's family home, the
## group chat, act cards) play on a manga page, a screentone wash with ink panel borders.
## Esc leaves the story for the title (progress is saved after every beat).


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var page := Page.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(page)
	if not InputMap.has_action("hub_menu"):
		InputMap.add_action("hub_menu")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("hub_menu", e)
	if not StoryMode.active:
		StoryMode.resume(get_tree())
		return
	var director := StoryDirector.new()
	director.name = "StoryDirector"
	director.stage = "panel"
	add_child(director)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hub_menu"):
		StoryMode.quit_to_title(get_tree())


## Paper, a dot screentone fading down the page, and three ink panel frames.
class Page extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), MangaType.PAPER)
		var step := 14.0
		var y := 0.0
		while y < size.y:
			var r := 2.6 * (y / size.y)
			if r > 0.3:
				var x := fmod(y / step, 2.0) * step * 0.5
				while x < size.x:
					draw_circle(Vector2(x, y), r, Color(MangaType.INK, 0.22))
					x += step
			y += step
		var m := 36.0
		var gutter := 18.0
		var top := Rect2(m, m, size.x - 2 * m, size.y * 0.42)
		var left := Rect2(m, top.end.y + gutter, size.x * 0.38, size.y - top.end.y - gutter - m)
		var right := Rect2(left.end.x + gutter, left.position.y, size.x - left.end.x - gutter - m, left.size.y)
		for r in [top, left, right]:
			draw_rect(r, MangaType.INK, false, 5.0)
