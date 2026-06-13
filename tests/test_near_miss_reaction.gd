extends GutTest
## NearMissReaction (CP 1.8): the flinch clock + cooldown gating + closeness
## scaling. Pure timer math — the flinch's on-screen feel is Ludo's playtest.


func test_idle_has_no_flinch() -> void:
	var r := NearMissReaction.new()
	assert_false(r.is_flinching())
	assert_eq(r.intensity(), 0.0)


func test_graze_fires_a_flinch() -> void:
	var r := NearMissReaction.new()
	assert_true(r.graze(1.0), "first graze triggers")
	assert_true(r.is_flinching())
	assert_almost_eq(r.intensity(), 1.0, 0.001, "full strength right after a max-closeness graze")


func test_closeness_scales_the_flinch() -> void:
	var r := NearMissReaction.new()
	r.graze(0.3)
	assert_almost_eq(r.intensity(), 0.3, 0.001)


func test_closeness_is_clamped() -> void:
	var r := NearMissReaction.new()
	r.graze(5.0)
	assert_almost_eq(r.intensity(), 1.0, 0.001, "closeness can't overdrive the flinch")


func test_intensity_decays_over_the_window() -> void:
	var r := NearMissReaction.new()
	r.graze(1.0)
	r.tick(NearMissReaction.FLINCH_DURATION * 0.5)
	assert_almost_eq(r.intensity(), 0.5, 0.001, "halfway through, half strength")
	r.tick(NearMissReaction.FLINCH_DURATION * 0.5)
	assert_eq(r.intensity(), 0.0, "window elapsed")
	assert_false(r.is_flinching())


func test_cooldown_gates_retriggers() -> void:
	var r := NearMissReaction.new()
	r.graze(1.0)
	assert_false(r.graze(1.0), "a fresh graze inside the cooldown is ignored")
	r.tick(NearMissReaction.COOLDOWN)
	assert_true(r.graze(1.0), "off cooldown, it can flinch again")
