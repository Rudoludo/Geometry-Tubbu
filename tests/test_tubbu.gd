extends GutTest
## Tubbu death & revive (CP 1.4): pure kill-gate state. The ships stay OUT of
## the tree on purpose — no trail, no burst, no frames — so this is the i-frame
## rule and the restart reset, nothing visual (testing rules).


func _make_tubbu() -> Tubbu:
	return autofree(Tubbu.new())


func test_kill_lands_on_a_live_ship() -> void:
	var tubbu := _make_tubbu()
	assert_true(tubbu.is_alive())
	assert_true(tubbu.try_kill(), "one hit, one death")
	assert_false(tubbu.is_alive())


func test_a_dead_ship_cannot_die_again() -> void:
	var tubbu := _make_tubbu()
	tubbu.try_kill()
	assert_false(tubbu.try_kill(), "no double-kill on a corpse")


func test_dash_iframes_block_the_kill() -> void:
	# The whole point of the dash. Reaches into _dash because no public path
	# can start a dash without device input; the gate itself is what's tested.
	var tubbu := _make_tubbu()
	tubbu._dash.try_dash(Vector2.RIGHT)
	assert_true(tubbu.is_invulnerable(), "sanity: dash just granted i-frames")
	assert_false(tubbu.try_kill(), "kills bounce off i-frames")
	assert_true(tubbu.is_alive())


func test_revive_resets_into_play() -> void:
	var tubbu := _make_tubbu()
	tubbu.velocity = Vector2(300.0, 0.0)
	tubbu.try_kill()
	tubbu.revive(Vector2(120.0, -40.0))
	assert_true(tubbu.is_alive())
	assert_true(tubbu.visible, "ship is visible again")
	assert_eq(tubbu.position, Vector2(120.0, -40.0))
	assert_eq(tubbu.velocity, Vector2.ZERO, "no carried-over momentum")
