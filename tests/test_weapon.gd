extends GutTest
## Weapon cadence (CP 1.2): pure timer math — rate, instant first shot, no
## banking. Feel (how it reads on screen) is Ludo's playtest, not a test.


func test_first_shot_is_immediate() -> void:
	var weapon := Weapon.new()
	assert_eq(weapon.tick(0.016, true), 1, "tap-fire must not wait a period")


func test_sustained_fire_matches_fire_rate() -> void:
	var weapon := Weapon.new()
	var shots := 0
	# 0.95 s of 60 fps frames — a hair under a second so the count can't ride
	# the float boundary where the Nth fire period lands exactly on 1.0 s.
	for i in 57:
		shots += weapon.tick(1.0 / 60.0, true)
	assert_eq(shots, int(Weapon.FIRE_RATE),
		"a second of sustained fire yields FIRE_RATE shots")


func test_not_firing_yields_no_shots() -> void:
	var weapon := Weapon.new()
	assert_eq(weapon.tick(1.0, false), 0)


func test_idle_time_banks_no_shots() -> void:
	var weapon := Weapon.new()
	weapon.tick(5.0, false)  # a long aim-neutral stretch...
	assert_eq(weapon.tick(0.016, true), 1,
		"...must buy exactly the one immediate shot, not a burst")


func test_long_frame_fires_multiple_shots() -> void:
	var weapon := Weapon.new()
	var period := 1.0 / Weapon.FIRE_RATE
	assert_eq(weapon.tick(period * 2.5, true), 3,
		"a hitch frame spanning N periods owes N shots (plus the immediate one)")
