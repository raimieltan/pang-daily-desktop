class_name StoryGarage
extends CanvasLayer
## Story mode's paper screens over a free-roam stop (docs/story/STORY_MODE.md "Free roam"):
## the talyer's garage (SHOP · TUNING · LEDGER, the wallet and Ruel's bill always in view) and
## Kapitan's board (the events open in this roam). Keyboard, gamepad and mouse; Esc backs out.
## `open_garage` / `open_board` return when the player leaves: the board returns the event picked.

signal closed(result: Dictionary)
## The car's setup or build changed (the director puts it on the car).
signal car_changed

const ROW := 496
const PAY_STEP := 1000

var _wash := ColorRect.new()
var _page := VBoxContainer.new()
var _money: Label
var _title: Label
var _tabs := HBoxContainer.new()
var _body := VBoxContainer.new()
var _hint: Label
var _tab := "shop"
var _mode := "garage"
var _events: Array = []
var _bars: Array[Control] = []
var _first: Control


func _ready() -> void:
	layer = 15
	visible = false
	_wash.color = Color(MangaType.PAPER, 0.93)
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_wash)
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.offset_left = 64
	_page.offset_top = 36
	_page.offset_right = -64
	_page.offset_bottom = -28
	_page.add_theme_constant_override("separation", 10)
	add_child(_page)
	_title = MangaType.label("", 56)
	_page.add_child(_title)
	_money = _slab("", MangaType.INK)
	_money.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_page.add_child(_money)
	_tabs.add_theme_constant_override("separation", 6)
	_page.add_child(_tabs)
	_body.add_theme_constant_override("separation", 2)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(_body)
	_hint = MangaType.label("", 24, MangaType.caption())
	_hint.add_theme_color_override("font_color", MangaType.INK)
	_hint.remove_theme_constant_override("outline_size")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(ROW * 1.8, 64)
	_page.add_child(_hint)


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("hub_menu")):
		get_viewport().set_input_as_handled()
		_leave({})


func open_garage(tab := "shop") -> Dictionary:
	_mode = "garage"
	_title.text = "TALYER NI RUEL"
	_tab = tab
	_show()
	return await closed


## The board: `events` from StoryBoard.events; returns the event picked, or {} for none.
func open_board(events: Array) -> Dictionary:
	_mode = "board"
	_title.text = "KAPITAN'S BOARD"
	_events = events
	_show()
	return await closed


func _show() -> void:
	visible = true
	_build()


func _leave(result: Dictionary) -> void:
	visible = false
	get_viewport().gui_release_focus()
	closed.emit(result)


func _build() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for c in _body.get_children():
		c.queue_free()
	_bars.clear()
	_first = null
	_money.text = _money_text()
	_hint.text = ""
	if _mode == "board":
		_build_board()
	else:
		for t in [["shop", "SHOP"], ["tune", "TUNING"], ["ledger", "LEDGER"]]:
			var b := _button(_tabs, ("▶ " if t[0] == _tab else "") + t[1], _switch.bind(t[0]), 210)
			if t[0] == _tab:
				_first = b
		match _tab:
			"shop":
				_build_shop()
			"tune":
				_build_tune()
			"ledger":
				_build_ledger()
	var done := _button(_body, "DONE", _leave.bind({}))
	done.focus_entered.connect(func(): _hint.text = "BACK TO THE CAR.")
	if _first == null:
		_first = done
	_first.grab_focus.call_deferred()


func _switch(tab: String) -> void:
	_tab = tab
	_build()


func _money_text() -> String:
	var text := "WALLET  ₱%s     RUEL'S BILL  ₱%s" % [_pesos(StoryMode.wallet()), _pesos(StoryMode.owed())]
	if StoryMode.timeline() == "memory" and not StoryMode.commitments.is_empty():
		text += "     JOLO OWES  ₱%s" % _pesos(StoryMode.commitments_total())
	return text


static func _pesos(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


# --- Shop -------------------------------------------------------------------------------------


func _build_shop() -> void:
	var build := StoryMode.car()
	var memory := StoryMode.timeline() == "memory"
	_body.add_child(_note("FRONTS %d%%   REARS %d%%   BR %d" % [roundi(CarParts.wear(build, "front") * 100.0),
		roundi(CarParts.wear(build, "rear") * 100.0), CarParts.rating(build)]))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	_body.add_child(grid)
	var posted := _posted_time()
	for it in StoryShop.ITEMS:
		var id: String = it["id"]
		var status := StoryShop.status(id)
		if status == StoryShop.Status.HIDDEN:
			continue
		var b := _button(grid, _shop_text(it, status), _buy.bind(id), ROW)
		b.focus_entered.connect(func():
			var lines := ["RUEL:  " + StoryShop.ruel_line(id)]
			if memory and it.has("jolo"):
				lines.append("JOLO:  " + it["jolo"])
			if StoryShop.shows_ghost_delta() and it["kind"] == "ego" and posted > 0.0:
				lines.append("vs GHOST TIME  %+.2f s" % StoryShop.ghost_delta(id, posted))
			_hint.text = "\n".join(lines))
		if _first == null or _first.get_parent() == _tabs:
			_first = b


func _shop_text(it: Dictionary, status: StoryShop.Status) -> String:
	var name: String = CarParts.PARTS[it["id"]]["name"]
	var tag := "RUEL" if it["kind"] == "ruel" else "EGO"
	match status:
		StoryShop.Status.FITTED:
			return "%s   ·   FITTED" % name
		StoryShop.Status.ORDER:
			return "%s   ·   ORDER · 2 WEEKS" % name
		StoryShop.Status.ON_ORDER:
			return "%s   ·   ON ORDER" % name
	var cost := StoryShop.price(it["id"])
	if it["id"] == "rain_set" and StoryMode.timeline() == "present":
		return "%s   ₱%s ON THE BILL" % [name, _pesos(cost)]
	return "%s   %s   [%s]" % [name, "FREE" if cost == 0 else "₱" + _pesos(cost), tag]


func _buy(id: String) -> void:
	var it := StoryShop.item(id)
	var status := StoryShop.status(id)
	if status == StoryShop.Status.ORDER:
		_hint.text = "RUEL:  It comes when it comes. After Friday."
		return
	if status != StoryShop.Status.BUY:
		return
	if not StoryShop.buy(id):
		_hint.text = "RUEL:  That's ₱%s. You've got ₱%s." % [_pesos(StoryShop.price(id)), _pesos(StoryMode.wallet())]
		return
	car_changed.emit()
	_build()
	for row in _body.find_children("*", "Button", true, false):
		if (row as Button).text.begins_with(CarParts.PARTS[id]["name"]):
			(row as Button).grab_focus.call_deferred()
	# After the focus lands (it writes the part's hint), Ruel's word on the purchase.
	(func(): _hint.text = "RUEL:  " + it["bought"]).call_deferred()


func _posted_time() -> float:
	var g := StoryMode.ghost_line()
	return StoryMode.posted_time(g.time) if g.valid() else 0.0


# --- Tuning -----------------------------------------------------------------------------------


func _build_tune() -> void:
	_body.add_child(_note("THE STORY CAR'S OWN SETUP. FREE TO CHANGE; FEEL IT ON THE NEXT RUN."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	_body.add_child(row)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	row.add_child(left)
	row.add_child(right)
	for i in CarSetup.SLIDERS.size():
		var b := _setup_row(left if i < 5 else right, CarSetup.SLIDERS[i])
		if i == 0:
			_first = b
	var reset := _button(right, "RESET TO STOCK", func():
		StoryMode.car()["setup"] = {}
		car_changed.emit()
		_redraw(), ROW)
	reset.focus_entered.connect(func(): _hint.text = "EVERY SLIDER BACK TO 0.")


func _setup_row(parent: Control, slider: Dictionary) -> Button:
	var key: String = slider["key"]
	var change := func(v: int) -> void:
		StoryMode.car()["setup"][key] = clampi(v, CarSetup.LO, CarSetup.HI)
		car_changed.emit()
		_redraw()
	var value := func() -> int: return CarSetup.steps(StoryMode.car()["setup"], key)
	var b := _button(parent, slider["label"], func():
		var v: int = value.call()
		change.call(CarSetup.LO if v >= CarSetup.HI else v + 1), ROW)
	var bar := GameMenu.SetupBar.new()
	bar.button = b
	bar.value = value
	b.add_child(bar)
	_bars.append(bar)
	b.focus_entered.connect(func():
		_hint.text = slider["hint"]
		bar.queue_redraw())
	b.focus_exited.connect(bar.queue_redraw)
	b.gui_input.connect(func(e: InputEvent) -> void:
		var step := -1 if e.is_action_pressed("ui_left") else (1 if e.is_action_pressed("ui_right") else 0)
		if step != 0:
			b.accept_event()
			change.call(clampi(value.call() + step, CarSetup.LO, CarSetup.HI)))
	return b


func _redraw() -> void:
	for bar in _bars:
		bar.queue_redraw()


# --- Ledger -----------------------------------------------------------------------------------


func _build_ledger() -> void:
	var lines := ["RUEL'S CLIPBOARD"]
	for entry in StoryMode.ledgers.get(StoryMode.timeline(), []):
		lines.append("%s %s ₱%s" % [str(entry[0]), ".".repeat(maxi(3, 34 - str(entry[0]).length())), _pesos(int(entry[1]))])
	lines.append("OWED  ₱%s" % _pesos(StoryMode.owed()))
	if StoryMode.timeline() == "memory" and not StoryMode.commitments.is_empty():
		lines.append("")
		lines.append("JOLO'S NOTES  (NOT YOURS TO PAY)")
		for entry in StoryMode.commitments:
			lines.append("%s  ₱%s" % [str(entry[0]), _pesos(int(entry[1]))])
	var text := _note("\n".join(lines))
	_body.add_child(text)
	var pay := _button(_body, "PAY ₱%s" % _pesos(PAY_STEP), _pay.bind(PAY_STEP), ROW)
	pay.focus_entered.connect(func(): _hint.text = "RUEL:  Pay when you can.")
	_first = pay
	var all := _button(_body, "PAY WHAT I CAN", _pay.bind(1 << 30), ROW)
	all.focus_entered.connect(func(): _hint.text = "EVERYTHING IN THE WALLET, UP TO WHAT YOU OWE.")


func _pay(pesos: int) -> void:
	var paid := StoryMode.pay_bill(pesos)
	_build()
	_hint.text = "RUEL:  " + ("Noted." if paid > 0 else "Nothing to pay with.")


# --- Board ------------------------------------------------------------------------------------


func _build_board() -> void:
	if _events.is_empty():
		_body.add_child(_note("NOTHING ON THE BOARD."))
	for e in _events:
		var text := _event_text(e)
		var b := _button(_body, text, _pick.bind(e), ROW * 2)
		b.focus_entered.connect(func(): _hint.text = _event_hint(e))
		if _first == null:
			_first = b


func _event_text(e: Dictionary) -> String:
	if e.get("done", false):
		return "%s   ·   RAN" % e["title"]
	var pay := ""
	if e["kind"] == "clock":
		pay = "PAYS UP TO ₱%s" % _pesos(int(e["bands"][0][1]))
	else:
		pay = "WIN ₱%s" % _pesos(int(e["purse"][0]))
	return "%s   ·   IN ₱%s   ·   %s" % [e["title"], _pesos(int(e["entry"])), pay]


func _event_hint(e: Dictionary) -> String:
	if e.get("done", false):
		return "ONE NIGHT, ONE RUN. IT'S DONE."
	if e["kind"] == "clock":
		var rows := []
		for band in e["bands"]:
			rows.append("UNDER %s  ₱%s" % [TimeAttackRun.format_time(float(band[0])), _pesos(int(band[1]))])
		return "ONE RUN, DOWNHILL, KAPITAN'S STOPWATCH.  " + "   ".join(rows)
	if e["kind"] == "downhill":
		return "PASS 1 DOWNHILL AGAINST %s AND %s." % [e["field"][0][0], e["field"][1][0]]
	return "ONE LAP OF THE LOOP. " + str(StoryBoard.REGULARS[int(e["regular"])]["hello"]).to_upper()


func _pick(e: Dictionary) -> void:
	if e.get("done", false):
		return
	if StoryMode.wallet() < int(e["entry"]):
		_hint.text = "ENTRY'S ₱%s. YOU'VE GOT ₱%s." % [_pesos(int(e["entry"])), _pesos(StoryMode.wallet())]
		return
	_leave(e)


# --- Paper ------------------------------------------------------------------------------------


func _note(text: String) -> Label:
	var l := MangaType.label(text, 22, MangaType.caption())
	l.add_theme_color_override("font_color", MangaType.INK)
	l.remove_theme_constant_override("outline_size")
	return l


func _slab(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	MangaType.ink(l, 24, MangaType.caption())
	l.add_theme_color_override("font_color", MangaType.PAPER)
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", box)
	return l


func _button(parent: Control, text: String, action: Callable, width := 340) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.x = width
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	MangaType.ink(b, 20)
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(MangaType.PAPER, 0.0)
	plain.set_content_margin_all(4)
	plain.content_margin_left = 14
	var lit := StyleBoxFlat.new()
	lit.bg_color = MangaType.INK
	lit.set_content_margin_all(4)
	lit.content_margin_left = 14
	lit.shadow_color = MangaType.INK
	lit.shadow_size = 1
	lit.shadow_offset = Vector2(6, 6)
	for state in ["normal", "disabled"]:
		b.add_theme_stylebox_override(state, plain)
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(state, lit)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, MangaType.PAPER)
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
