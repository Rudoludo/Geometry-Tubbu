extends GutTest
## ScreenShake trauma model (CP 1.6): the pure 0..1 trauma curve the camera
## maps onto pixels. Pixels, randomness and the actual camera motion are feel —
## not tested. Only the math here is (testing rule: pure logic only).

const EPS := 0.0001


func test_starts_calm() -> void:
	var shake := ScreenShake.new()
	assert_eq(shake.trauma(), 0.0)
	assert_false(shake.has_shake())
	assert_eq(shake.shake(), 0.0)


func test_adding_trauma_raises_the_shake() -> void:
	var shake := ScreenShake.new()
	shake.add(0.5)
	assert_almost_eq(shake.trauma(), 0.5, EPS)
	assert_true(shake.has_shake())


func test_trauma_clamps_to_one() -> void:
	# Stacked swarm kills can't overdrive past full.
	var shake := ScreenShake.new()
	shake.add(0.8)
	shake.add(0.8)
	assert_almost_eq(shake.trauma(), 1.0, EPS, "trauma saturates at 1")


func test_shake_is_trauma_squared() -> void:
	# Squaring is the whole point: small bumps barely move, big ones slam.
	var shake := ScreenShake.new()
	shake.add(0.4)
	assert_almost_eq(shake.shake(), 0.16, EPS)


func test_trauma_decays_over_time() -> void:
	var shake := ScreenShake.new()
	shake.add(1.0)
	shake.tick(0.1)
	assert_almost_eq(shake.trauma(), 1.0 - ScreenShake.DECAY * 0.1, EPS)


func test_decay_never_goes_negative() -> void:
	var shake := ScreenShake.new()
	shake.add(0.1)
	shake.tick(10.0)  # far more than enough to drain it
	assert_eq(shake.trauma(), 0.0, "trauma floors at zero, never inverts")
	assert_false(shake.has_shake())
