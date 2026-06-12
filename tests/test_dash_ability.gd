extends GutTest
## DashAbility (CP 1.3): cooldown timing + the i-frame window state machine.
## Pure clock math — dash *feel* (speed, ghost) is Ludo's playtest.


func test_ready_from_the_start() -> void:
	var dash := DashAbility.new()
	assert_true(dash.is_ready())
	assert_false(dash.is_dashing())
	assert_false(dash.is_invulnerable())


func test_dash_starts_and_grants_iframes() -> void:
	var dash := DashAbility.new()
	assert_true(dash.try_dash(Vector2.UP))
	assert_true(dash.is_dashing())
	assert_true(dash.is_invulnerable())
	assert_false(dash.is_ready())


func test_direction_is_normalized() -> void:
	var dash := DashAbility.new()
	dash.try_dash(Vector2(10.0, 0.0))
	assert_almost_eq(dash.direction(), Vector2.RIGHT, Vector2(0.001, 0.001))


func test_zero_direction_is_rejected() -> void:
	var dash := DashAbility.new()
	assert_false(dash.try_dash(Vector2.ZERO))
	assert_true(dash.is_ready(), "a rejected dash must not start the cooldown")


func test_dash_window_ends_but_cooldown_continues() -> void:
	var dash := DashAbility.new()
	dash.try_dash(Vector2.UP)
	dash.tick(DashAbility.DASH_DURATION + 0.001)
	assert_false(dash.is_dashing(), "impulse window over")
	assert_false(dash.is_invulnerable(), "i-frames over")
	assert_false(dash.is_ready(), "still cooling down")


func test_cooldown_blocks_until_elapsed() -> void:
	var dash := DashAbility.new()
	dash.try_dash(Vector2.UP)
	dash.tick(DashAbility.COOLDOWN * 0.5)
	assert_false(dash.try_dash(Vector2.UP), "mid-cooldown dash refused")
	dash.tick(DashAbility.COOLDOWN * 0.5)
	assert_true(dash.try_dash(Vector2.UP), "ready again exactly at COOLDOWN")


func test_iframes_run_on_their_own_clock() -> void:
	# CP 2.7 lengthens I_FRAMES independently of DASH_DURATION; the window
	# must track its own constant, not piggyback on the dash state.
	var dash := DashAbility.new()
	dash.try_dash(Vector2.UP)
	dash.tick(DashAbility.I_FRAMES * 0.5)
	assert_true(dash.is_invulnerable(), "mid-window")
	dash.tick(DashAbility.I_FRAMES * 0.5 + 0.001)
	assert_false(dash.is_invulnerable(), "window elapsed")


func test_cooldown_fraction_refills_zero_to_one() -> void:
	var dash := DashAbility.new()
	assert_almost_eq(dash.cooldown_fraction(), 1.0, 0.001, "full before any dash")
	dash.try_dash(Vector2.UP)
	assert_almost_eq(dash.cooldown_fraction(), 0.0, 0.001, "empty at dash start")
	dash.tick(DashAbility.COOLDOWN * 0.5)
	assert_almost_eq(dash.cooldown_fraction(), 0.5, 0.001, "refills linearly")
	dash.tick(DashAbility.COOLDOWN * 0.5)
	assert_almost_eq(dash.cooldown_fraction(), 1.0, 0.001, "full when ready")
