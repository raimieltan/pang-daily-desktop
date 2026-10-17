extends Node3D
## The barangay hub: drive the neighbourhood, hang out at Kyo Coffee, challenge rivals.
## Rivals parked at Kyo: pull up beside one and press E. Rivals cruising the loop: get behind one
## and flash your lights (L). Either way the SP battle runs on Pass 1, then E brings you back here.
## The talyer's bays swap your car (Ruel); the east end of the main road heads up to Pass 1.
## Esc: the title menu. R: back onto the loop.

const CHALLENGE_REACH := 7.5
const FLASH_REACH := 40.0

var session: DriveSession
var loop: TrackData
var cruise_track: TrackData
var parked: Array[CarBody] = []
var parked_rivals: Array[int] = []
var cruisers: Array[CarBody] = []
var cruiser_drivers: Array[AiDriver] = []
var cruiser_rivals: Array[int] = []
var _ring := 0
var _place := ""
var _hud: CanvasLayer
var _toast: Label
var _hint: Label
var _prompt: Label
var _line: Label
var _toast_time := 0.0
var _action := Callable()
var _leaving := false
var _builder: HubBuilder
var _lights_on := -1


func _ready() -> void:
	_register_actions()
	var env := WorldEnvironment.new()
	env.environment = MangaArt.environment()
	add_child(env)
	add_child(MangaArt.sun())
	_builder = HubBuilder.new()
	_builder.build(self)
	loop = HubLayout.loop_track(1)
	cruise_track = HubLayout.loop_track(3)
	_ring = loop.points.size() - 1

	var where: Dictionary = HubLayout.PLACES.get(HubChallenge.return_to, HubLayout.PLACES["kyo"])
	var s: Vector3 = where["spawn"]
	session = DriveSession.new(HubLayout.pos(s.x, s.y, 0.3), HubLayout.yaw(s.z))
	session.reset_pose = func(car: CarBody) -> Dictionary:
		return loop.pose_at(loop.nearest_index(car.global_position) * loop.spacing, 2.0)
	session.track = loop
	if StoryMode.active:
		session.car_spec = CarRoster.get_car(StoryMode.CAR_ID)
		session.paint = StoryMode.CAR_PAINT
	elif HubChallenge.car_id != "":
		session.car_spec = CarRoster.get_car(HubChallenge.car_id)
	add_child(session)
	session.minimap.track = loop
	var ambience := Ambience.new()
	ambience.listener = session.camera
	add_child(ambience)

	for spot in HubLayout.KYO_PARKED:
		var car := _spawn_car(spot[0], HubLayout.pos(spot[1], spot[2], 0.3), HubLayout.yaw(spot[3]))
		car.input_source = func() -> VehicleTypes.DriverInput:
			return VehicleTypes.DriverInput.make(0.0, 1.0, 0.0, 1.0, "ai")
		parked.append(car)
		parked_rivals.append(spot[0])
	_park_lights_off.call_deferred()
	# In the story the loop is the meet's course: nobody cruising it.
	if not StoryMode.active:
		for k in HubLayout.CRUISERS.size():
			_spawn_cruiser(HubLayout.CRUISERS[k], 260.0 + k * _ring * 0.5)
	var others: Array = [session.car]
	others.append_array(cruisers)
	for d in cruiser_drivers:
		d.others = others
	session.minimap.rivals.assign(cruisers)
	_build_hud()
	HubChallenge.return_to = "kyo"
	if StoryMode.active:
		_hud.visible = false
		var director := StoryDirector.new()
		director.name = "StoryDirector"
		director.stage = "hub"
		director.session = session
		director.loop = loop
		add_child(director)


## Parked cars keep their lamps dark: nosed in at Kyo, their beams would white out the glass.
## (CarVisual builds its spots a frame late, so this runs deferred, twice over.)
func _park_lights_off(again := true) -> void:
	for car in parked:
		for spot in car.find_children("*", "SpotLight3D", true, false):
			(spot as SpotLight3D).light_cull_mask = 0
	if again:
		_park_lights_off.call_deferred(false)


func _register_actions() -> void:
	# flash_lights (L) is PlayerInput's; registered here too in case it is not there yet.
	for pair in [["interact", KEY_E, JOY_BUTTON_X], ["hub_menu", KEY_ESCAPE, JOY_BUTTON_START],
			["flash_lights", KEY_L, JOY_BUTTON_Y]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var e := InputEventKey.new()
		e.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], e)
		var b := InputEventJoypadButton.new()
		b.button_index = pair[2]
		InputMap.action_add_event(pair[0], b)


func _spawn_car(rival: int, at: Vector3, heading: float) -> CarBody:
	var spec: Dictionary = VsBattle.RIVALS[rival]
	var car := CarBody.new()
	car.name = "Rival_%s" % spec["name"].replace(" ", "_")
	car.preset = spec["preset"]
	car.tire_product = "street"
	add_child(car)
	car.global_position = at
	car.rotation.y = heading
	var visual := CarVisual.new()
	visual.model_scene = load(spec["model"])
	visual.paint_color = spec["paint"]
	visual.car = car
	car.add_child(visual)
	car.place(at, heading)
	return car


## A rival driving the loop at town speed, in the right-hand lane, giving way like traffic.
func _spawn_cruiser(rival: int, distance: float) -> void:
	var pose := cruise_track.pose_at(distance, 1.6)
	var car := _spawn_car(rival, pose["position"], pose["heading"])
	var driver := AiDriver.new(car, cruise_track, 0.55, 1.6)
	driver.racing = true
	car.input_source = func() -> VehicleTypes.DriverInput:
		var input := driver.input()
		var speed := car.linear_velocity.length()
		if speed > HubLayout.CRUISE_SPEED:
			input.throttle = 0.0
			input.brake = maxf(input.brake, clampf((speed - HubLayout.CRUISE_SPEED) * 0.15, 0.0, 0.5))
		return input
	cruisers.append(car)
	cruiser_drivers.append(driver)
	cruiser_rivals.append(rival)


func _physics_process(_delta: float) -> void:
	# The cruise road is the loop three times over: keep each driver in the middle lap.
	for d in cruiser_drivers:
		if d._index >= _ring * 2:
			d._index -= _ring


func _process(delta: float) -> void:
	if _hint:
		# The gearbox can change in the menu: the shift keys show only with the manual.
		_hint.text = "E  TALK     L  FLASH LIGHTS     R  RESET     " \
			+ ("I / O  SHIFT     " if GameSettings.value("transmission") == "manual" else "") + "ESC  MENU"
	var on := 1 if MangaArt.night > 0.5 else 0
	if on != _lights_on:
		_lights_on = on
		for light in _builder.lights:
			light.visible = on == 1
	if _leaving or session.car == null:
		return
	var p := session.car.global_position
	var at := Vector2(p.x, -p.z)
	var place := ""
	for key in HubLayout.PLACES:
		if (HubLayout.PLACES[key]["area"] as Rect2).has_point(at):
			place = key
	if place != _place:
		_place = place
		if place != "":
			_show_toast(HubLayout.PLACES[place]["name"])
	_toast_time -= delta
	_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	_update_prompt(at)


func _update_prompt(at: Vector2) -> void:
	if StoryMode.active:
		return
	var speed := session.car.linear_velocity.length()
	_action = Callable()
	var text := ""
	var line := ""
	if speed < 3.0:
		var best := -1
		var best_d := CHALLENGE_REACH
		for k in parked.size():
			var d := parked[k].global_position.distance_to(session.car.global_position)
			if d < best_d:
				best_d = d
				best = k
		if best >= 0:
			var spec: Dictionary = VsBattle.RIVALS[parked_rivals[best]]
			text = "E   CHALLENGE %s" % spec["name"]
			line = "%s  ·  \"%s\"" % [spec["car"], HubLayout.LINES.get(spec["name"], "")]
			_action = _challenge.bind(parked_rivals[best])
		elif Rect2(8.5, 151, 31, 16.5).has_point(at):
			var next := _next_car()
			text = "E   SWAP TO THE %s" % next["name"]
			line = "RUEL:  \"%s\"" % HubLayout.RUEL
			_action = _swap_car.bind(next["id"])
	if text == "" and _place == "exit":
		text = "E   HEAD UP TO PASS 1"
		_action = _to_pass
	_prompt.text = text
	_prompt.visible = text != ""
	_line.text = line
	_line.visible = line != ""


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if StoryMode.active:
		if event.is_action_pressed("hub_menu"):
			_leaving = true
			StoryMode.quit_to_title(get_tree())
		return
	if event.is_action_pressed("interact") and _action.is_valid():
		_action.call()
	elif event.is_action_pressed("flash_lights"):
		_flash()
	elif event.is_action_pressed("hub_menu"):
		_leaving = true
		HubChallenge.rival = -1
		get_tree().change_scene_to_file(HubChallenge.PASS_SCENE)


## Flash the headlights: a cruiser just ahead in your lane takes it as a challenge.
func _flash() -> void:
	if session.visual.has_method("flash"):
		session.visual.call("flash")
	var me := session.car
	var forward := -me.global_basis.z
	for k in cruisers.size():
		var to := cruisers[k].global_position - me.global_position
		var ahead := to.dot(forward)
		if ahead > 3.0 and ahead < FLASH_REACH and absf(to.dot(me.global_basis.x)) < 4.0:
			var spec: Dictionary = VsBattle.RIVALS[cruiser_rivals[k]]
			_show_toast("%s FLASHES BACK!" % spec["name"])
			_line.text = "\"%s\"" % HubLayout.LINES.get(spec["name"], "")
			_line.visible = true
			_leaving = true
			get_tree().create_timer(1.6).timeout.connect(_challenge.bind(cruiser_rivals[k]))
			return


func _challenge(rival: int) -> void:
	_leaving = true
	HubChallenge.start(get_tree(), rival, session.car_spec["id"])


func _to_pass() -> void:
	_leaving = true
	HubChallenge.free_drive = true
	HubChallenge.car_id = session.car_spec["id"]
	get_tree().change_scene_to_file(HubChallenge.PASS_SCENE)


func _next_car() -> Dictionary:
	var cars := CarRoster.CARS
	for i in cars.size():
		if cars[i]["id"] == session.car_spec["id"]:
			return cars[(i + 1) % cars.size()]
	return cars[0]


func _swap_car(id: String) -> void:
	session.set_car(id)
	HubChallenge.car_id = id
	_show_toast(session.car_spec["name"])


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.5


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 8
	add_child(_hud)
	_toast = MangaType.label("", 56)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 40
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_hud.add_child(_toast)
	_line = MangaType.label("", 30, MangaType.caption())
	_line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_line.position.y = 170
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_line)
	_prompt = MangaType.label("", 30)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y = 118
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_prompt)
	_hint = MangaType.label("", 20, MangaType.caption())
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.position = Vector2(24, -40)
	_hud.add_child(_hint)
	_show_toast(HubLayout.PLACES[HubChallenge.return_to]["name"] if HubLayout.PLACES.has(HubChallenge.return_to) else "BARANGAY")
