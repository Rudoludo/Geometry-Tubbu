extends GutTest
## IdleAnimation (CP 1.8): the pure squash/bob/blink curves. Frame-time math
## only — how it reads on screen is Ludo's feel gate, not a test.


func _anim() -> IdleAnimation:
	var a := IdleAnimation.new()
	a.bob_amplitude = 4.0
	a.breathe_amplitude = 0.1
	a.cycle_time = 2.0
	a.blink_interval = 3.0
	return a


func test_bob_and_breathe_start_at_rest() -> void:
	var a := _anim()
	assert_almost_eq(a.bob(), 0.0, 0.001, "sin(0) — no offset at t=0")
	assert_almost_eq(a.breathe(), 0.0, 0.001)


func test_bob_peaks_at_a_quarter_cycle() -> void:
	var a := _anim()
	a.tick(a.cycle_time * 0.25)  # sin(pi/2) = 1
	assert_almost_eq(a.bob(), a.bob_amplitude, 0.001)
	assert_almost_eq(a.breathe(), a.breathe_amplitude, 0.001)


func test_breathe_stays_within_amplitude() -> void:
	var a := _anim()
	for i in 40:
		a.tick(0.05)
		assert_between(a.breathe(), -a.breathe_amplitude - 0.001, a.breathe_amplitude + 0.001)


func test_eye_is_open_at_rest_and_between_blinks() -> void:
	var a := _anim()
	assert_almost_eq(a.blink_openness(), 1.0, 0.001, "open at t=0")
	a.tick(1.0)  # mid-interval, past the blink window
	assert_almost_eq(a.blink_openness(), 1.0, 0.001, "open between blinks")


func test_eye_shuts_at_the_middle_of_a_blink() -> void:
	var a := _anim()
	a.tick(IdleAnimation.BLINK_DURATION * 0.5)  # peak of the blink
	assert_almost_eq(a.blink_openness(), 0.0, 0.001, "fully shut")


func test_blink_repeats_each_interval() -> void:
	var a := _anim()
	a.tick(a.blink_interval)                          # start of the next interval
	a.tick(IdleAnimation.BLINK_DURATION * 0.5)        # into its blink
	assert_almost_eq(a.blink_openness(), 0.0, 0.001, "blinks again next cycle")


func test_zero_periods_are_safe() -> void:
	var a := IdleAnimation.new()
	a.cycle_time = 0.0
	a.blink_interval = 0.0
	a.tick(0.5)
	assert_eq(a.bob(), 0.0, "no divide-by-zero bob")
	assert_eq(a.breathe(), 0.0)
	assert_eq(a.blink_openness(), 1.0, "no blink means always open")
