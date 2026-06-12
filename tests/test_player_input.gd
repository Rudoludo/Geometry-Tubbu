extends GutTest
## PlayerInput (CP 0.2): device binding + pure input math. Per testing rules
## these never touch feel — only binding state, edge latching, deadzone math.


func after_each() -> void:
	Input.action_release(InputActions.DASH)


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


func test_kbm_autofire_is_always_on() -> void:
	# Design rule: kb+m has no trigger — the mouse aims, fire never stops.
	var input := PlayerInput.for_keyboard_mouse()
	assert_true(input.is_fire_held(Vector2.RIGHT))
	assert_true(input.is_fire_held(Vector2.ZERO),
		"even a degenerate aim must not silence the kb+m gun")


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
