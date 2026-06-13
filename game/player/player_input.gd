class_name PlayerInput
extends RefCounted
## Per-player input source, bound to one device family at a time.
##
## Co-op rule (PLAN.md): gameplay code never calls Input.* directly — each
## player owns a PlayerInput and reads intents (move / aim / fire / dash) from
## it. This class is the single place that touches the Input singleton.
##
## kb+m reads the InputMap actions (so key rebinding stays free later); the
## actions are keyboard/mouse ONLY. gamepad reads raw per-device axes/buttons,
## because InputMap actions aggregate every device and can't answer "what is
## *this* pad doing" once a second player exists. The two families never bleed
## into each other — input is exclusive (issue #4).
##
## [member mode] picks which family is active:
##   AUTO            — follow the last-used device (kb+m vs a gamepad), sticky.
##   KEYBOARD_MOUSE  — lock to kb+m; a pad does nothing.
##   GAMEPAD         — lock to one pad; the keyboard/mouse does nothing.
##
## The owner calls [method update] once per frame; reads are valid after it.

## The active device family — what reads actually come from.
enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }

## The policy for choosing [member device_kind]. AUTO resolves it each frame.
enum Mode { AUTO, KEYBOARD_MOUSE, GAMEPAD }

## Raw axis reads bypass the InputMap deadzone, so we apply our own.
## Same value as the move/aim actions in project.godot.
const STICK_DEADZONE := 0.2

## Inside this radius of the shooter the cursor has no usable direction;
## mouse aim holds the last good one instead of flickering.
const MOUSE_DEAD_RADIUS := 2.0

var mode := Mode.AUTO
var device_kind := DeviceKind.KEYBOARD_MOUSE
## Joypad device id for GAMEPAD bindings; -1 for kb+m.
var device_id := -1
## kb+m fire policy (issue #3): false = hold the FIRE button (left mouse) to
## shoot; true = always-on autofire (the old behavior, now opt-in). Set by Game
## from SettingsStore.autofire. Gamepad ignores this (its trigger is the stick).
var autofire := false

var _dash_pressed := false
var _dash_just_pressed := false
var _restart_pressed := false
var _restart_just_pressed := false
## Ships spawn facing +X, so that's the degenerate-mouse fallback too.
var _last_mouse_aim := Vector2.RIGHT


static func for_keyboard_mouse() -> PlayerInput:
	var input := PlayerInput.new()
	input.use_keyboard_mouse()
	return input


static func for_gamepad(joy_device_id: int) -> PlayerInput:
	var input := PlayerInput.new()
	input.use_gamepad(joy_device_id)
	return input


## Last-used-device binding (issue #1/#4): the active family follows whichever
## device the player touched most recently, resolved each [method update].
static func for_auto() -> PlayerInput:
	var input := PlayerInput.new()
	input.use_auto()
	return input


## Switch to last-used-device mode. Keeps the current [member device_kind] until
## the next [method update] re-resolves it (sticky — no flicker when idle).
func use_auto() -> void:
	mode = Mode.AUTO


func use_keyboard_mouse() -> void:
	mode = Mode.KEYBOARD_MOUSE
	device_kind = DeviceKind.KEYBOARD_MOUSE
	device_id = -1


func use_gamepad(joy_device_id: int) -> void:
	mode = Mode.GAMEPAD
	device_kind = DeviceKind.GAMEPAD
	device_id = joy_device_id


## Latches button edges. Call once per frame, before reading. In AUTO mode this
## also re-resolves which device family is active from recent activity.
func update() -> void:
	if mode == Mode.AUTO:
		_resolve_auto_device()
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
## cursor is always somewhere.
func get_aim_vector(shooter: Node2D) -> Vector2:
	if device_kind == DeviceKind.GAMEPAD:
		return apply_deadzone(
			_read_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y), STICK_DEADZONE)
	var to_mouse := shooter.get_global_mouse_position() - shooter.global_position
	if to_mouse.length() > MOUSE_DEAD_RADIUS:
		_last_mouse_aim = to_mouse.normalized()
	return _last_mouse_aim


## The trigger rule. GAMEPAD: the right stick IS the trigger — deflection past
## the deadzone fires (so the aim already read this frame answers it, no second
## device read). KB+M (issue #3): hold the FIRE button (left mouse) to shoot,
## unless [member autofire] is on, which restores always-on fire. Unit-tested.
func is_fire_held(aim: Vector2) -> bool:
	if device_kind == DeviceKind.GAMEPAD:
		return aim != Vector2.ZERO
	return autofire or Input.is_action_pressed(InputActions.FIRE)


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


## AUTO: switch the active family to whatever the player just used. A pad wins
## the moment a stick deflects or a face/dash/start button is pressed; the
## keyboard/mouse wins on any of its actions. Neither active → keep the last one
## (sticky), so a resting pad doesn't surrender to mouse jitter and vice-versa.
func _resolve_auto_device() -> void:
	var pad := _first_active_gamepad()
	if pad != -1:
		device_kind = DeviceKind.GAMEPAD
		device_id = pad
	elif _keyboard_mouse_active():
		device_kind = DeviceKind.KEYBOARD_MOUSE
		device_id = -1


## The id of the first connected pad showing activity, or -1. Used only by AUTO.
func _first_active_gamepad() -> int:
	for pad in Input.get_connected_joypads():
		var left := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X),
				Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		var right := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X),
				Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
		if left.length() > STICK_DEADZONE or right.length() > STICK_DEADZONE:
			return pad
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER) \
				or Input.is_joy_button_pressed(pad, JOY_BUTTON_START) \
				or Input.is_joy_button_pressed(pad, JOY_BUTTON_A):
			return pad
	return -1


## Any keyboard/mouse activity this frame (the move actions are keyboard-only
## now, so a pad stick can't trip this). Used only by AUTO.
func _keyboard_mouse_active() -> bool:
	return Input.is_action_pressed(InputActions.MOVE_LEFT) \
			or Input.is_action_pressed(InputActions.MOVE_RIGHT) \
			or Input.is_action_pressed(InputActions.MOVE_UP) \
			or Input.is_action_pressed(InputActions.MOVE_DOWN) \
			or Input.is_action_pressed(InputActions.FIRE) \
			or Input.is_action_pressed(InputActions.DASH) \
			or Input.is_action_pressed(InputActions.RESTART) \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _read_stick(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	return Vector2(
		Input.get_joy_axis(device_id, axis_x),
		Input.get_joy_axis(device_id, axis_y))


func _read_dash_raw() -> bool:
	if device_kind == DeviceKind.GAMEPAD:
		# Mirrors the old dash action's pad binding (RB = 10).
		return Input.is_joy_button_pressed(device_id, JOY_BUTTON_RIGHT_SHOULDER)
	return Input.is_action_pressed(InputActions.DASH)


func _read_restart_raw() -> bool:
	if device_kind == DeviceKind.GAMEPAD:
		# Mirrors the old restart action's pad binding (Start = 6).
		return Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)
	return Input.is_action_pressed(InputActions.RESTART)
