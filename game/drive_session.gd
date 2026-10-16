class_name DriveSession
extends Node
## One player car in a map: the car, its visual, chase camera, HUD and driving hotkeys.
## Maps own the world; they hand the session a spawn and, optionally, a reset rule.

signal car_reset
signal car_changed

var car: CarBody
## The roster entry being driven (CarRoster.CARS).
var car_spec: Dictionary = CarRoster.CARS[0]
var visual: CarVisual
var camera: ChaseCamera
var hud: TelemetryHud
var fx: CarFx
var audio: CarAudio
var day_night: DayNightSwitch
var camera_picker: CameraPicker
## Speedometer bottom-right, minimap top-left (the map sets `minimap.track`).
var gauges: CanvasLayer
var speedometer: Speedometer
var minimap: Minimap
## func(car: CarBody) -> Dictionary { "position": Vector3, "heading": float }; defaults to the spawn.
var reset_pose: Callable
## Optional func(DriverInput) -> DriverInput applied to the player's input (race starts, cutscenes).
var input_filter: Callable
## The map's road; the autopilot drives it. Set by the map.
var track: TrackData:
	set(t):
		track = t
		if camera:
			camera.director.track = t
## Drives the player's car when set (P, or the SPECTATE mode). Input filters still apply.
var autopilot: AiDriver
## Records the run; F plays it back. Modes call `replay.begin()` when a run starts.
var replay: Replay
## U: every HUD layer hidden, for clean footage.
var clean_feed := false
var _hud_before := {}
var _auto_chip: Label
var _input := PlayerInput.new()
var _spawn := { "position": Vector3.ZERO, "heading": 0.0 }


func _init(spawn_position: Vector3, spawn_heading: float) -> void:
	_spawn = { "position": spawn_position, "heading": spawn_heading }


func _ready() -> void:
	PlayerInput.register_actions()
	car = CarBody.new()
	car.name = "PlayerCar"
	car.input_source = _read_input
	car.preset = car_spec["preset"]
	add_child(car)
	car.global_position = _spawn["position"]
	car.rotation.y = _spawn["heading"]
	_add_visual()
	car.place(_spawn["position"], _spawn["heading"])

	camera = ChaseCamera.new()
	camera.target = car
	add_child(camera)
	camera.current = true
	camera.snap.call_deferred()

	fx = CarFx.new()
	fx.car = car
	fx.camera = camera
	add_child(fx)

	audio = CarAudio.new()
	audio.car = car
	add_child(audio)

	day_night = DayNightSwitch.new()
	add_child(day_night)

	if track:
		camera.director.track = track
	replay = Replay.new()
	replay.session = self
	add_child(replay)

	camera_picker = CameraPicker.new()
	camera_picker.camera = camera
	camera_picker.add_to_group(&"play_hud")
	add_child(camera_picker)
	day_night.add_to_group(&"play_hud")

	hud = TelemetryHud.new()
	hud.car = car
	add_child(hud)

	gauges = CanvasLayer.new()
	gauges.layer = 9
	add_child(gauges)
	speedometer = Speedometer.new()
	speedometer.car = car
	speedometer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speedometer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	speedometer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speedometer.offset_left = -290
	speedometer.offset_top = -290
	speedometer.offset_right = -30
	speedometer.offset_bottom = -30
	gauges.add_child(speedometer)
	minimap = Minimap.new()
	minimap.player = car
	minimap.position = Vector2(24, 24)
	gauges.add_child(minimap)
	gauges.add_to_group(&"play_hud")
	hud.add_to_group(&"play_hud")
	_auto_chip = MangaType.label("AUTOPILOT  [P]", 26)
	_auto_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_auto_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# Under the day/night switch and clear of the centre HUD (timer, run-up line, SP gauges).
	_auto_chip.position = Vector2(-300, 236)
	_auto_chip.visible = false
	gauges.add_child(_auto_chip)
	for pair in [["autopilot", KEY_P], ["clean_feed", KEY_U]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var e := InputEventKey.new()
			e.physical_keycode = pair[1]
			InputMap.action_add_event(pair[0], e)


func _add_visual() -> void:
	visual = CarVisual.new()
	visual.model_scene = load(car_spec["model"])
	visual.car = car
	car.add_child(visual)


## Swap to another roster car: its tune on the sim, its body on screen. Tires carry over.
func set_car(id: String) -> void:
	var spec := CarRoster.get_car(id)
	if spec == car_spec:
		return
	car_spec = spec
	car.set_preset(spec["preset"])
	car.set_tire_product(car.tire_product)
	if visual:
		car.remove_child(visual)
		visual.queue_free()
	_add_visual()
	car_changed.emit()


func _read_input() -> VehicleTypes.DriverInput:
	var input := _input.read()
	if autopilot:
		input = autopilot.input()
		# Past the finish it eases to a stop like a rival.
		autopilot.cooldown = track.finish_distance > 0.0 and autopilot.distance >= track.finish_distance
	return input_filter.call(input) if input_filter.is_valid() else input


## Hand the wheel to an AI driver (skill 1.0, its lane where the car is now), or take it back.
func set_autopilot(on: bool) -> void:
	if on == (autopilot != null) or (on and track == null):
		return
	if on:
		var i := track.nearest_index(car.global_position)
		var lane := clampf(track.lateral_offset(car.global_position, i), -1.7, 1.7)
		autopilot = AiDriver.new(car, track, 1.0, lane)
		autopilot.racing = true
	else:
		autopilot = null
	_auto_chip.visible = on


## Hide every HUD layer (or bring them back as they were).
func set_clean_feed(on: bool) -> void:
	clean_feed = on
	if on:
		_hud_before.clear()
		for n in get_tree().get_nodes_in_group(&"play_hud"):
			_hud_before[n] = n.visible
			n.visible = false
	else:
		for n in _hud_before:
			if is_instance_valid(n):
				n.visible = _hud_before[n]
		_hud_before.clear()


func _process(_delta: float) -> void:
	if clean_feed:
		# Menus and modes re-show their HUDs; keep the feed clean until U again.
		for n in get_tree().get_nodes_in_group(&"play_hud"):
			if n.visible and n != replay:
				if not _hud_before.has(n):
					_hud_before[n] = true
				n.visible = false


func reset_car() -> void:
	var pose: Dictionary = reset_pose.call(car) if reset_pose.is_valid() else _spawn
	car.place(pose["position"], pose["heading"])
	car.global_position = pose["position"]
	car.rotation = Vector3(0.0, pose["heading"], 0.0)
	camera.snap.call_deferred()
	car_reset.emit()


func _unhandled_input(event: InputEvent) -> void:
	if replay and replay.playing and not (event.is_action_pressed("clean_feed") or event.is_action_pressed("toggle_night")):
		return
	if event.is_action_pressed("reset_car"):
		reset_car()
	elif event.is_action_pressed("toggle_tune"):
		car.toggle_tune()
	elif event.is_action_pressed("toggle_tires"):
		car.set_tire_product("street" if car.tire_product == "stock" else "stock")
	elif event.is_action_pressed("toggle_night"):
		day_night.toggle()
	elif event.is_action_pressed("autopilot"):
		set_autopilot(autopilot == null)
	elif event.is_action_pressed("clean_feed"):
		set_clean_feed(not clean_feed)
	elif event.is_action_pressed("toggle_hud"):
		hud.debug_visible = not hud.debug_visible
