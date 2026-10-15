class_name PlayerInput
extends RefCounted
## Keyboard and gamepad → `DriverInput`. Registers its input actions at runtime, so the project
## needs no hand-edited InputMap. Keyboard input is digital; the sim's assistance shapes it.

const ACTIONS := {
	"throttle": [KEY_W, KEY_UP],
	"brake": [KEY_S, KEY_DOWN],
	"steer_left": [KEY_A, KEY_LEFT],
	"steer_right": [KEY_D, KEY_RIGHT],
	"handbrake": [KEY_SPACE],
	"reset_car": [KEY_R],
	"toggle_tune": [KEY_T],
	"toggle_tires": [KEY_Y],
	"toggle_hud": [KEY_H],
	"toggle_night": [KEY_N],
}

var _last_device := "keyboard"


static func register_actions() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.1)
		for key in ACTIONS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
	_add_axis("throttle", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	for pair in [["handbrake", JOY_BUTTON_A], ["handbrake", JOY_BUTTON_B], ["reset_car", JOY_BUTTON_BACK]]:
		var b := InputEventJoypadButton.new()
		b.button_index = pair[1]
		InputMap.action_add_event(pair[0], b)


static func _add_axis(action: String, axis: JoyAxis, direction: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = direction
	InputMap.action_add_event(action, e)


func read() -> VehicleTypes.DriverInput:
	var input := VehicleTypes.DriverInput.new()
	input.throttle = Input.get_action_strength("throttle")
	input.brake = Input.get_action_strength("brake")
	input.steer = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	input.handbrake = Input.get_action_strength("handbrake")
	# Analog sticks get controller assistance; any key press switches back to keyboard tuning.
	var analog := Input.get_connected_joypads().size() > 0 and (
		absf(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)) > 0.15 or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.05
		or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.05)
	var keys := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_A) \
		or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_DOWN) \
		or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_RIGHT)
	if analog:
		_last_device = "controller"
	elif keys:
		_last_device = "keyboard"
	input.device = _last_device
	return input
