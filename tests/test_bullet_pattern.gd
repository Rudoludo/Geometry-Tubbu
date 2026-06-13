extends GutTest
## BulletPattern math (CP 1.5): pure ring/aimed-burst direction generation. No
## scene, no feel — just that the angles come out where the boss (CP 3.5) and
## the pattern shooter will rely on them (testing rule: pure logic only).

const EPS := 0.0001
const VEC_EPS := Vector2(0.0001, 0.0001)


# --- ring -------------------------------------------------------------------

func test_ring_of_zero_is_empty() -> void:
	assert_eq(BulletPattern.ring(0).size(), 0)
	assert_eq(BulletPattern.ring(-3).size(), 0, "negative counts are empty too")


func test_ring_of_one_fires_along_the_phase() -> void:
	var dirs := BulletPattern.ring(1, 0.0)
	assert_eq(dirs.size(), 1)
	assert_almost_eq(dirs[0], Vector2.RIGHT, VEC_EPS, "phase 0 = +X")


func test_ring_of_four_hits_the_cardinals() -> void:
	# Godot is Y-down: angle PI/2 is DOWN, not UP.
	var dirs := BulletPattern.ring(4, 0.0)
	assert_almost_eq(dirs[0], Vector2.RIGHT, VEC_EPS)
	assert_almost_eq(dirs[1], Vector2.DOWN, VEC_EPS)
	assert_almost_eq(dirs[2], Vector2.LEFT, VEC_EPS)
	assert_almost_eq(dirs[3], Vector2.UP, VEC_EPS)


func test_ring_directions_are_unit_and_evenly_spaced() -> void:
	var count := 7
	var dirs := BulletPattern.ring(count, 0.3)
	var step := TAU / count
	for i in count:
		assert_almost_eq(dirs[i].length(), 1.0, EPS, "every direction is a unit vector")
		var next := dirs[(i + 1) % count]
		assert_almost_eq(dirs[i].angle_to(next), step, EPS, "equal angular spacing")


func test_ring_phase_rotates_the_whole_ring() -> void:
	var phase := 0.55
	var base := BulletPattern.ring(5, 0.0)
	var rotated := BulletPattern.ring(5, phase)
	for i in base.size():
		assert_almost_eq(rotated[i], base[i].rotated(phase), VEC_EPS)


# --- aimed_burst ------------------------------------------------------------

func test_aimed_burst_without_a_direction_is_empty() -> void:
	assert_eq(BulletPattern.aimed_burst(Vector2.ZERO, 5, 0.4).size(), 0,
		"a zero aim has nothing to centre on")
	assert_eq(BulletPattern.aimed_burst(Vector2.RIGHT, 0, 0.4).size(), 0)


func test_single_aimed_shot_goes_straight_at_the_target() -> void:
	var dirs := BulletPattern.aimed_burst(Vector2(3.0, 4.0), 1, 0.4)
	assert_eq(dirs.size(), 1)
	assert_almost_eq(dirs[0], Vector2(3.0, 4.0).normalized(), VEC_EPS)


func test_aimed_burst_fans_symmetrically_around_the_aim() -> void:
	var spread := deg_to_rad(30.0)
	var dirs := BulletPattern.aimed_burst(Vector2.RIGHT, 3, spread)
	assert_eq(dirs.size(), 3)
	assert_almost_eq(dirs[1], Vector2.RIGHT, VEC_EPS, "the middle shot is dead-on")
	# Endpoints sit at +/- half the spread off the aim.
	assert_almost_eq(dirs[0], Vector2.from_angle(-spread * 0.5), VEC_EPS)
	assert_almost_eq(dirs[2], Vector2.from_angle(spread * 0.5), VEC_EPS)
	for dir in dirs:
		assert_almost_eq(dir.length(), 1.0, EPS)


func test_aimed_burst_recentres_on_an_angled_target() -> void:
	var aim := Vector2.from_angle(deg_to_rad(120.0))
	var spread := deg_to_rad(40.0)
	var dirs := BulletPattern.aimed_burst(aim, 2, spread)
	# Two shots straddle the aim: their average direction points back at it.
	var mid := (dirs[0] + dirs[1]).normalized()
	assert_almost_eq(mid, aim, VEC_EPS)
