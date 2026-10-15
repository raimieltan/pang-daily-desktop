class_name DriveSession
extends Node
## One player car in a map: the car, its visual, chase camera, HUD and driving hotkeys.
## Maps own the world; they hand the session a spawn and, optionally, a reset rule.

signal car_reset

var car: CarBody
var camera: ChaseCamera
var hud: TelemetryHud
var fx: CarFx
var audio: CarAudio
var day_night: DayNightSwitch
var camera_picker: CameraPicker
## func(car: CarBody) -> Dictionary { "position": Vector3, "heading": float }; defaults to the spawn.
var reset_pose: Callable
## Optional func(DriverInput) -> DriverInput applied to the player's input (race starts, cutscenes).
var input_filter: Callable
var _input := PlayerInput.new()
var _spawn := { "position": Vector3.ZERO, "heading": 0.0 }


func _init(spawn_position: Vector3, spawn_heading: float) -> void:
	_spawn = { "position": spawn_position, "heading": spawn_heading }


func _ready() -> void:
	PlayerInput.register_actions()
	car = CarBody.new()
	car.name = "PlayerCar"
	car.input_source = _read_input
	add_child(car)
	car.global_position = _spawn["position"]
	car.rotation.y = _spawn["heading"]
	var visual := CarVisual.new()
	visual.car = car
	car.add_child(visual)
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

	camera_picker = CameraPicker.new()
	camera_picker.camera = camera
	add_child(camera_picker)

	hud = TelemetryHud.new()
	hud.car = car
	add_child(hud)


func _read_input() -> VehicleTypes.DriverInput:
	var input := _input.read()
	return input_filter.call(input) if input_filter.is_valid() else input


func reset_car() -> void:
	var pose: Dictionary = reset_pose.call(car) if reset_pose.is_valid() else _spawn
	car.place(pose["position"], pose["heading"])
	car.global_position = pose["position"]
	car.rotation = Vector3(0.0, pose["heading"], 0.0)
	camera.snap.call_deferred()
	car_reset.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_car"):
		reset_car()
	elif event.is_action_pressed("toggle_tune"):
		car.toggle_tune()
	elif event.is_action_pressed("toggle_tires"):
		car.set_tire_product("street" if car.tire_product == "stock" else "stock")
	elif event.is_action_pressed("toggle_night"):
		day_night.toggle()
	elif event.is_action_pressed("toggle_hud"):
		hud.debug_visible = not hud.debug_visible
