class_name RaceHud
extends CanvasLayer
## Time-attack HUD in manga lettering (docs/ART_DIRECTION.md §7): ink and paper only, heavy
## outlined numerals, a speech-burst countdown, split deltas, and a GOAL panel.

const PAPER := MangaType.PAPER
const INK := MangaType.INK

var _timer: Label
var _best: Label
var _split: Label
var _countdown: Label
var _goal: PanelContainer
var _goal_text: Label
var _place: Label
var _place_of: Label
## SP battle gauges, [0] the player (left), [1] the rival (right).
var _sp: Array[SpGauge] = []
var _split_timer := 0.0
var _count_value := -1


func _ready() -> void:
	layer = 10
	_timer = _label(42, Control.PRESET_CENTER_TOP, Vector2(0, 26))
	_best = _label(24, Control.PRESET_CENTER_TOP, Vector2(0, 84), MangaType.caption())
	_split = _label(28, Control.PRESET_CENTER_TOP, Vector2(0, 112))
	_countdown = _label(150, Control.PRESET_CENTER, Vector2(0, -60))
	# Battle position, big on the left like a panel number: "2" over "/4".
	_place = _label(120, Control.PRESET_CENTER_LEFT, Vector2(46, -40))
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place.grow_horizontal = Control.GROW_DIRECTION_END
	_place_of = _label(34, Control.PRESET_CENTER_LEFT, Vector2(52, 90), MangaType.caption())
	_place_of.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place_of.grow_horizontal = Control.GROW_DIRECTION_END
	for i in 2:
		var g := SpGauge.new()
		g.mirrored = i == 0
		g.fill = INK if i == 0 else MangaType.RED
		g.set_anchors_preset(Control.PRESET_CENTER_TOP)
		g.position = Vector2(-g.custom_minimum_size.x - 18 if i == 0 else 18, 150)
		g.size = g.custom_minimum_size
		g.visible = false
		add_child(g)
		_sp.append(g)
	_goal = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = INK
	style.set_border_width_all(6)
	style.set_content_margin_all(28)
	style.shadow_color = MangaType.INK
	style.shadow_size = 1
	style.shadow_offset = Vector2(10, 10)
	_goal.add_theme_stylebox_override("panel", style)
	_goal.set_anchors_preset(Control.PRESET_CENTER)
	_goal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_goal.grow_vertical = Control.GROW_DIRECTION_BOTH
	_goal_text = Label.new()
	MangaType.ink(_goal_text, 30)
	_goal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal.add_child(_goal_text)
	add_child(_goal)
	_goal.visible = false


func _label(size: int, preset: int, offset: Vector2, font: Font = null) -> Label:
	var l := Label.new()
	MangaType.pop(l, size, font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(preset)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.position += offset
	add_child(l)
	return l


func show_run(best: Dictionary) -> void:
	_goal.visible = false
	_show_sp(false)
	_place.text = ""
	_place_of.text = ""
	_split.text = ""
	_best.text = "BEST  " + (TimeAttackRun.format_time(float(best["time"])) if best.has("time") else "--:--.---")
	_count_value = -1


func go() -> void:
	shout("GO!!")


## A burst in the countdown spot: GO!!, BATTLE!!, CHALLENGE!!
func shout(text: String) -> void:
	_countdown.text = text
	# Countdown digits at full size; longer words shrink to stay on screen.
	_countdown.add_theme_font_size_override("font_size", 150 if text.length() <= 4 else int(150 * 5.5 / text.length()))
	_countdown.pivot_offset = _countdown.size / 2.0
	_countdown.scale = Vector2.ONE * 1.3
	_count_value = 0
	var tween := create_tween()
	tween.tween_property(_countdown, "scale", Vector2.ONE, 0.25)
	tween.tween_interval(0.5)
	tween.tween_callback(func(): _countdown.text = "")


func split(sector: int, time: float, reference: float) -> void:
	if reference < 0.0:
		_split.text = "S%d  %s" % [sector + 1, TimeAttackRun.format_time(time)]
	else:
		var delta := time - reference
		_split.text = "S%d  %s%.3f" % [sector + 1, "+" if delta >= 0.0 else "−", absf(delta)]
	_split_timer = 3.0


func finish(time: float, previous_best: float, record: bool) -> void:
	var lines := ["G O A L", "", TimeAttackRun.format_time(time)]
	if record:
		lines.append("NEW RECORD!" if previous_best > 0.0 else "FIRST RECORD")
		if previous_best > 0.0:
			lines.append("−%.3f" % (previous_best - time))
	else:
		lines.append("BEST  " + TimeAttackRun.format_time(previous_best))
	lines.append("")
	lines.append("[ENTER] RUN AGAIN")
	_goal_text.text = "\n".join(lines)
	_goal.visible = true


## `frozen` ≥ 0 holds the timer at that time (a decided SP battle).
func update_run(run: TimeAttackRun, frozen := -1.0) -> void:
	_timer.text = TimeAttackRun.format_time(frozen if frozen >= 0.0 else run.time)
	if run.phase == TimeAttackRun.Phase.COUNTDOWN:
		var n := int(ceil(run.countdown))
		if n != _count_value:
			_count_value = n
			_countdown.text = str(n)
			_countdown.add_theme_font_size_override("font_size", 150)
			_countdown.pivot_offset = _countdown.size / 2.0
			_countdown.scale = Vector2.ONE * 1.4
			create_tween().tween_property(_countdown, "scale", Vector2.ONE, 0.2)
	_split_timer = maxf(0.0, _split_timer - get_process_delta_time())
	if _split_timer == 0.0:
		_split.text = ""


## A battle instead of a time attack: the rivals' names where the best time goes.
func show_versus(names: Array) -> void:
	_goal.visible = false
	_split.text = ""
	_best.text = "VS  " + "  ·  ".join(names)
	_count_value = -1
	_show_sp(false)
	_place.text = ""
	_place_of.text = ""


func set_place(place: int, of: int) -> void:
	_place.text = str(place)
	_place_of.text = ["", "ST", "ND", "RD"][place] + "  /  %d" % of if place <= 3 else "TH  /  %d" % of


func versus_result(place: int, time: float, standings: String) -> void:
	var head := "WIN!!" if place == 1 else ("%d%s PLACE" % [place, ["", "ST", "ND", "RD", "TH"][mini(place, 4)]])
	_goal_text.text = "\n".join([head, "", TimeAttackRun.format_time(time), "", standings, "", "[ENTER] REMATCH"])
	_goal.visible = true
	_place.text = ""
	_place_of.text = ""


## An SP battle: the two gauges under the timer, full, the rival's name on the right one.
func show_sp(rival: String) -> void:
	_best.text = "SP BATTLE  ·  VS  " + rival
	_sp[1].label = rival
	for g in _sp:
		g.set_state(SpBattleRules.FULL, false)
	_show_sp(true)


func _show_sp(on: bool) -> void:
	for g in _sp:
		g.visible = on


## `lead` is the leading car's distance, for the run-up countdown to the SP line; `rolling` is a
## paced start from the grid (a challenge on the road just counts down to the line).
func update_sp(rules: SpBattleRules, lead: float, rolling := true) -> void:
	if rules.phase == SpBattleRules.Phase.ROLLING and _count_value == 0:
		var line := "SP LINE %d m" % maxi(0, ceili(rules.arm_distance - lead))
		_split.text = ("ROLLING START  ·  " + line) if rolling else line
		_split_timer = 0.2
	for i in 2:
		_sp[i].set_state(rules.sp[i], rules.phase == SpBattleRules.Phase.BATTLE and rules.trailing == i)


## The gauge arms after the rolling run-up.
func sp_armed() -> void:
	shout("BATTLE!!")


func sp_result(rules: SpBattleRules, rival: String, time: float) -> void:
	var win := rules.winner == 0
	var why := ""
	if rules.reason == "sp":
		why = ("%s IS OUT OF SP" % rival) if win else "OUT OF SP"
	else:
		why = "ROAD END  ·  MORE SP WINS"
	_goal_text.text = "\n".join([
		"WIN!!" if win else "LOSE...", why, "",
		"YOU  %d     %s  %d" % [ceili(rules.sp[0]), rival, ceili(rules.sp[1])],
		TimeAttackRun.format_time(time), "", "[ENTER] REMATCH"])
	_goal.visible = true
