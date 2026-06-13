extends GutTest
## PlayerInput (CP 0.2): device binding + pure input math. Per testing rules
## these never touch feel — only binding state, edge latching, deadzone math.


func after_each() -> void:
	Input.action_release(InputActions.DASH)
	Input.action_release(InputActions.FIRE)


func test_keyboard_mouse_binding() -> void:
	var input := PlayerInput.for_keyboard_mouse()
	assert_eq(input.device_kind, PlayerInput.DeviceKind.KEYBOARD_MOUSE)
	assert_eq(input.device_id, -1, "kb+m has no joypad device")


func test_gamepad_binding_keeps_device_id() -> void:
	var input := PlayerInput.for_gamepad(2)
	assert_eq(input.device_kind, PlayerInput.DeviceKind.GAMEPAD)
	assert_eq(input.device_id, 2)


func test_gamepad_bindings_are_per_device() -> void:
	assert_ne(
		PlayerInput.for_gamepad(0).device_id,
		PlayerInput.for_gamepad(1).device_id,
		"two pads must not share a binding")


func test_unplugged_gamepad_reads_neutral() -> void:
	# Headless: no pad exists on device 7; raw reads must come back neutral,
	# never error.
	var input := PlayerInput.for_gamepad(7)
	input.update()
	var shooter: Node2D = autofree(Node2D.new())
	assert_eq(input.get_move_vector(), Vector2.ZERO)
	assert_eq(input.get_aim_vector(shooter), Vector2.ZERO)
	assert_false(input.is_dash_pressed())


func test_gamepad_stick_is_the_trigger() -> void:
	# Design rule: deflection past the deadzone IS the fire input.
	var input := PlayerInput.for_gamepad(0)
	assert_false(input.is_fire_held(Vector2.ZERO), "neutral stick holds fire")
	assert_true(input.is_fire_held(Vector2(0.3, 0.0)), "deflected stick fires")


func test_kbm_fire_follows_the_fire_button() -> void:
	# Issue #3: kb+m fires only while the FIRE button (left mouse) is held.
	var input := PlayerInput.for_keyboard_mouse()
	assert_false(input.is_fire_held(Vector2.RIGHT), "idle gun does not fire")
	Input.action_press(InputActions.FIRE)
	assert_true(input.is_fire_held(Vector2.RIGHT), "held fire button shoots")
	Input.action_release(InputActions.FIRE)
	assert_false(input.is_fire_held(Vector2.RIGHT), "release stops the gun")


func test_kbm_autofire_toggle_forces_fire() -> void:
	# Issue #3: the opt-in autofire toggle restores always-on kb+m fire.
	var input := PlayerInput.for_keyboard_mouse()
	input.autofire = true
	assert_true(input.is_fire_held(Vector2.ZERO),
		"autofire fires with no button and even a degenerate aim")


func test_explicit_modes_lock_the_device_family() -> void:
	# Issue #4: an explicitly chosen family stays put (no auto-switch).
	var kbm := PlayerInput.for_keyboard_mouse()
	assert_eq(kbm.mode, PlayerInput.Mode.KEYBOARD_MOUSE)
	kbm.use_gamepad(3)
	assert_eq(kbm.mode, PlayerInput.Mode.GAMEPAD)
	assert_eq(kbm.device_kind, PlayerInput.DeviceKind.GAMEPAD)
	assert_eq(kbm.device_id, 3)


func test_auto_mode_starts_sticky_and_does_not_error() -> void:
	# AUTO resolves the active family from device activity each update(); headless
	# with no input it keeps its current (default kb+m) family and never errors.
	var input := PlayerInput.for_auto()
	assert_eq(input.mode, PlayerInput.Mode.AUTO)
	input.update()
	assert_eq(input.device_kind, PlayerInput.DeviceKind.KEYBOARD_MOUSE)


func test_kbm_dash_edge_latching() -> void:
	var input := PlayerInput.for_keyboard_mouse()
	input.update()
	assert_false(input.is_dash_just_pressed(), "no dash before press")
	Input.action_press(InputActions.DASH)
	input.update()
	assert_true(input.is_dash_just_pressed(), "edge fires on press frame")
	input.update()
	assert_true(input.is_dash_pressed(), "still held next frame")
	assert_false(input.is_dash_just_pressed(), "edge fires only once")
	Input.action_release(InputActions.DASH)
	input.update()
	assert_false(input.is_dash_pressed())


func test_deadzone_inside_is_zero() -> void:
	assert_eq(PlayerInput.apply_deadzone(Vector2(0.1, 0.1), 0.2), Vector2.ZERO)


func test_deadzone_rescales_from_zero() -> void:
	# Just past the deadzone the output is near zero — no magnitude jump.
	var out := PlayerInput.apply_deadzone(Vector2(0.25, 0.0), 0.2)
	assert_between(out.length(), 0.0001, 0.1)
	assert_almost_eq(out.normalized(), Vector2.RIGHT, Vector2(0.001, 0.001),
		"direction preserved")


func test_deadzone_full_deflection_is_unit() -> void:
	var out := PlayerInput.apply_deadzone(Vector2(1.0, 0.0), 0.2)
	assert_almost_eq(out.length(), 1.0, 0.001)


func test_deadzone_clamps_overdriven_sticks() -> void:
	# Diagonal raw reads can exceed length 1 on real hardware.
	var out := PlayerInput.apply_deadzone(Vector2(1.0, 1.0), 0.2)
	assert_almost_eq(out.length(), 1.0, 0.001)
