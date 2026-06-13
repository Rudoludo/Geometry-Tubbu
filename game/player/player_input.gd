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

## Inside this radius of the shooter the cursor has no usable direction;
## mouse aim holds the last good one instead of flickering.
const MOUSE_DEAD_RADIUS := 2.0

var device_kind := DeviceKind.KEYBOARD_MOUSE
## Joypad device id for GAMEPAD bindings; -1 for kb+m.
var device_id := -1

var _dash_pressed := false
var _dash_just_pressed := false
var _restart_pressed := false
var _restart_just_pressed := false
## Ships spawn facing +X, so that's the degenerate-mouse fallback too.
var _last_mouse_aim := Vector2.RIGHT


static func for_keyboard_mouse() -> PlayerInput:
	return PlayerInput.new()


static func for_gamepad(joy_device_id: int) -> PlayerInput:
	var input := PlayerInput.new()
	input.device_kind = DeviceKind.GAMEPAD
	input.device_id = joy_device_id
	return input


## Latches button edges. Call once per frame, before reading.
func update() -> void:
	var dash_now := _read_dash_raw()
	_dash_just_pressed = dash_now and not _dash_pressed
	_dash_pressed = dash_now
	var restart_now := _read_restart_raw()
	_restart_just_pressed = restart_now and not _restart_pressed
	_restart_pressed = restart_now


## Movement intent, length 0..1, deadzoned.
func get_move_vector() -> Vector2:
	if device_kind == DeviceKind.GAMEPAD:
		return apply_deadzone(
			_read_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y), STICK_DEADZONE)
	return Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_UP, InputActions.MOVE_DOWN)


## Aim intent.
## GAMEPAD: right-stick deflection, deadzoned (length 0..1). ZERO means "not
## aiming" — which per design also means "not firing" (stick = trigger).
## KB+M: unit vector from `shooter` toward the mouse cursor, in world space.
## The cursor only becomes a direction relative to a world anchor, so the
## reading ship passes itself; the gamepad path ignores it. Never zero — the
## cursor is always somewhere — matching the design's always-on kb+m autofire
## (see [method is_fire_held]).
func get_aim_vector(shooter: Node2D) -> Vector2:
	if device_kind == DeviceKind.GAMEPAD:
		return apply_deadzone(
			_read_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y), STICK_DEADZONE)
	var to_mouse := shooter.get_global_mouse_position() - shooter.global_position
	if to_mouse.length() > MOUSE_DEAD_RADIUS:
		_last_mouse_aim = to_mouse.normalized()
	return _last_mouse_aim


## The trigger rule (DESIGN.md): the right stick IS the trigger — deflection
## past the deadzone fires; kb+m has no trigger at all, autofire is always on.
## Takes the aim already read this frame so the policy lives here without a
## second device read. Pure; unit-tested.
func is_fire_held(aim: Vector2) -> bool:
	if device_kind == DeviceKind.GAMEPAD:
		return aim != Vector2.ZERO
	return true


func is_dash_pressed() -> bool:
	return _dash_pressed


func is_dash_just_pressed() -> bool:
	return _dash_just_pressed


## Instant-restart intent (CP 1.4). Read by Game, not the ship — restarting
## resets the whole sandbox, but the *device* is still per-player (co-op rule).
func is_restart_just_pressed() -> bool:
	return _restart_just_pressed


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


func _read_restart_raw() -> bool:
	if device_kind == DeviceKind.GAMEPAD:
		# Mirrors the restart action's pad binding in project.godot (Start = 6).
		return Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)
	return Input.is_action_pressed(InputActions.RESTART)
