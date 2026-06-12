class_name PlayerInput
extends RefCounted
## Per-player input source, bound to one device.
##
## Co-op rule (PLAN.md): gameplay code never calls Input.* directly — each
## player owns a PlayerInput and reads intents (move / aim / dash) from it.
## This class is the single place that touches the Input singleton.
##
## kb+m reads the InputMap actions (so key rebinding stays free later);
## gamepad reads raw per-device axes/buttons, because InputMap actions
## aggregate every device and can't answer "what is *this* pad doing" once a
## second player exists.
##
## The owner calls [method update] once per frame; reads are valid after it.

enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }

## Raw axis reads bypass the InputMap deadzone, so we apply our own.
## Same value as the move/aim actions in project.godot.
const STICK_DEADZONE := 0.2

var device_kind := DeviceKind.KEYBOARD_MOUSE
## Joypad device id for GAMEPAD bindings; -1 for kb+m.
var device_id := -1

var _dash_pressed := false
var _dash_just_pressed := false


static func for_keyboard_mouse() -> PlayerInput:
	return PlayerInput.new()


static func for_gamepad(joy_device_id: int) -> PlayerInput:
	var input := PlayerInput.new()
	input.device_kind = DeviceKind.GAMEPAD
	input.device_id = joy_device_id
	return input


## Latches dash edges. Call once per frame, before reading.
func update() -> void:
	var now_pressed := _read_dash_raw()
	_dash_just_pressed = now_pressed and not _dash_pressed
	_dash_pressed = now_pressed


## Movement intent, length 0..1, deadzoned.
func get_move_vector() -> Vector2:
	if device_kind == DeviceKind.GAMEPAD:
		return apply_deadzone(
			_read_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y), STICK_DEADZONE)
	return Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_UP, InputActions.MOVE_DOWN)


## Stick aim direction, length 0..1 (zero inside the deadzone — CP 1.2 uses
## "past deadzone" as the fire trigger). kb+m aims with the mouse, which needs
## a world-space anchor; that path lands in CP 1.2 (aim & autofire).
func get_aim_vector() -> Vector2:
	if device_kind == DeviceKind.GAMEPAD:
		return apply_deadzone(
			_read_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y), STICK_DEADZONE)
	return Vector2.ZERO


func is_dash_pressed() -> bool:
	return _dash_pressed


func is_dash_just_pressed() -> bool:
	return _dash_just_pressed


## Radial deadzone with rescale: zero inside, then the remaining range maps to
## 0..1 — so deflection just past the deadzone starts gently instead of
## jumping. Pure math, unit-tested.
static func apply_deadzone(raw: Vector2, deadzone: float) -> Vector2:
	var length := raw.length()
	if length <= deadzone:
		return Vector2.ZERO
	var rescaled := (length - deadzone) / (1.0 - deadzone)
	return raw / length * minf(rescaled, 1.0)


func _read_stick(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	return Vector2(
		Input.get_joy_axis(device_id, axis_x),
		Input.get_joy_axis(device_id, axis_y))


func _read_dash_raw() -> bool:
	if device_kind == DeviceKind.GAMEPAD:
		# Mirrors the dash action's pad binding in project.godot (RB = 10).
		return Input.is_joy_button_pressed(device_id, JOY_BUTTON_RIGHT_SHOULDER)
	return Input.is_action_pressed(InputActions.DASH)
