extends GutTest
## BulletManager pool (CP 1.2): acquire/release/exhaustion + cull logic, driven
## deterministically through step() — no frames, no feel, per testing rules.

const CAP := BulletManager.PLAYER_BULLET_CAPACITY

var _bm: BulletManager


func before_each() -> void:
	_bm = BulletManager.new()
	add_child_autofree(_bm)


func _fill_pool(direction: Vector2) -> void:
	for i in CAP:
		_bm.spawn_player_bullet(0, Vector2.ZERO, direction)


func test_spawn_acquires_slots() -> void:
	_bm.spawn_player_bullet(0, Vector2.ZERO, Vector2.RIGHT)
	_bm.spawn_player_bullet(0, Vector2.ZERO, Vector2.UP)
	assert_eq(_bm.active_player_bullet_count(), 2)


func test_bullets_move_along_their_direction() -> void:
	_bm.spawn_player_bullet(0, Vector2.ZERO, Vector2.RIGHT)
	_bm.step(0.1)
	var bullet: Dictionary = _bm.debug_player_bullets()[0]
	assert_almost_eq(bullet["position"],
		Vector2(BulletManager.PLAYER_BULLET_SPEED * 0.1, 0.0), Vector2(0.001, 0.001))


func test_ttl_expiry_releases_slot() -> void:
	_bm.spawn_player_bullet(0, Vector2.ZERO, Vector2.RIGHT)
	_bm.step(BulletManager.PLAYER_BULLET_TTL + 0.01)
	assert_eq(_bm.active_player_bullet_count(), 0, "TTL is the no-bounds backstop")


func test_leaving_bounds_releases_slot_before_ttl() -> void:
	_bm.bounds = Rect2(-100.0, -100.0, 200.0, 200.0)
	_bm.spawn_player_bullet(0, Vector2.ZERO, Vector2.RIGHT)
	_bm.step(0.2)  # 230 px > the 100 px to the wall; far inside the 1.2 s TTL
	assert_eq(_bm.active_player_bullet_count(), 0)


func test_released_slots_are_reusable() -> void:
	_fill_pool(Vector2.RIGHT)
	_bm.step(BulletManager.PLAYER_BULLET_TTL + 0.01)
	assert_eq(_bm.active_player_bullet_count(), 0)
	_fill_pool(Vector2.UP)
	assert_eq(_bm.active_player_bullet_count(), CAP, "a drained pool refills fully")


func test_exhaustion_recycles_the_oldest_bullet() -> void:
	# The first (oldest) bullet is the only one aimed RIGHT; everything else
	# goes UP. One spawn past capacity must replace it — never drop the new
	# shot (the gun would stutter) and never evict a younger bullet.
	_bm.spawn_player_bullet(0, Vector2.ZERO, Vector2.RIGHT)
	for i in CAP - 1:
		_bm.spawn_player_bullet(0, Vector2.ZERO, Vector2.UP)
	_bm.spawn_player_bullet(0, Vector2.ZERO, Vector2.DOWN)

	assert_eq(_bm.active_player_bullet_count(), CAP, "count never exceeds capacity")
	var right_count := 0
	var down_count := 0
	for bullet: Dictionary in _bm.debug_player_bullets():
		var dir: Vector2 = bullet["velocity"].normalized()
		if dir.is_equal_approx(Vector2.RIGHT):
			right_count += 1
		elif dir.is_equal_approx(Vector2.DOWN):
			down_count += 1
	assert_eq(right_count, 0, "oldest bullet was recycled")
	assert_eq(down_count, 1, "the over-capacity shot still fired")


func test_zero_direction_spawns_nothing() -> void:
	_bm.spawn_player_bullet(0, Vector2.ZERO, Vector2.ZERO)
	assert_eq(_bm.active_player_bullet_count(), 0, "no stationary bullets")


func test_clear_empties_the_pool() -> void:
	_fill_pool(Vector2.RIGHT)
	_bm.clear()
	assert_eq(_bm.active_player_bullet_count(), 0)


func test_owner_index_rides_with_the_bullet() -> void:
	# Co-op rule: kill attribution needs the firing player's index.
	_bm.spawn_player_bullet(1, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(_bm.debug_player_bullets()[0]["owner_index"], 1)


# --- collide_player_bullets (CP 1.4) ----------------------------------------

func _target_at(at: Vector2) -> Node2D:
	var target := Node2D.new()
	target.position = at
	add_child_autofree(target)  # in-tree so global_position is valid
	return target


func test_collision_consumes_the_bullet_and_reports_the_target() -> void:
	_bm.spawn_player_bullet(0, Vector2(50.0, 0.0), Vector2.RIGHT)
	var target := _target_at(Vector2(52.0, 0.0))
	var hits := _bm.collide_player_bullets([target], 10.0)
	assert_eq(hits, [target])
	assert_eq(_bm.active_player_bullet_count(), 0, "the hit eats the bullet")


func test_collision_misses_outside_the_radius() -> void:
	_bm.spawn_player_bullet(0, Vector2(50.0, 0.0), Vector2.RIGHT)
	var hits := _bm.collide_player_bullets([_target_at(Vector2(200.0, 0.0))], 10.0)
	assert_eq(hits.size(), 0)
	assert_eq(_bm.active_player_bullet_count(), 1, "a miss costs nothing")


func test_a_hit_target_soaks_no_further_bullets() -> void:
	# One bullet kills it; the second must survive to hit whatever is behind.
	_bm.spawn_player_bullet(0, Vector2(50.0, 0.0), Vector2.RIGHT)
	_bm.spawn_player_bullet(0, Vector2(51.0, 0.0), Vector2.RIGHT)
	var hits := _bm.collide_player_bullets([_target_at(Vector2(50.0, 0.0))], 10.0)
	assert_eq(hits.size(), 1, "a target dies once")
	assert_eq(_bm.active_player_bullet_count(), 1, "the corpse is not a shield")


func test_one_bullet_kills_at_most_one_target() -> void:
	# Pierce is a CP 2.5 upgrade, not a default.
	_bm.spawn_player_bullet(0, Vector2(50.0, 0.0), Vector2.RIGHT)
	var stacked := [_target_at(Vector2(50.0, 0.0)), _target_at(Vector2(51.0, 0.0))]
	var hits := _bm.collide_player_bullets(stacked, 10.0)
	assert_eq(hits.size(), 1, "no free pierce on overlapping targets")


# --- enemy band (CP 1.5) ----------------------------------------------------

func test_enemy_bullet_lives_in_its_own_band() -> void:
	_bm.spawn_enemy_bullet(Vector2.ZERO, Vector2(0.0, 100.0))
	assert_eq(_bm.active_enemy_bullet_count(), 1)
	assert_eq(_bm.active_player_bullet_count(), 0, "the two bands never share slots")


func test_enemy_bullet_moves_along_its_velocity() -> void:
	# The shooter owns the speed: the manager flies the exact velocity given.
	_bm.spawn_enemy_bullet(Vector2.ZERO, Vector2(100.0, 0.0))
	_bm.step(0.1)
	assert_almost_eq(_bm.debug_enemy_bullets()[0]["position"],
		Vector2(10.0, 0.0), Vector2(0.001, 0.001))


func test_enemy_bullet_ttl_cleanup() -> void:
	_bm.spawn_enemy_bullet(Vector2.ZERO, Vector2(0.0, 100.0))
	_bm.step(BulletManager.ENEMY_BULLET_TTL + 0.01)
	assert_eq(_bm.active_enemy_bullet_count(), 0, "TTL is the no-bounds backstop")


func test_enemy_bullet_leaving_bounds_releases_slot_before_ttl() -> void:
	_bm.bounds = Rect2(-100.0, -100.0, 200.0, 200.0)
	_bm.spawn_enemy_bullet(Vector2.ZERO, Vector2(2000.0, 0.0))
	_bm.step(0.2)  # 400 px > the 100 px to the wall; far inside the 8 s TTL
	assert_eq(_bm.active_enemy_bullet_count(), 0)


func test_zero_velocity_enemy_bullet_spawns_nothing() -> void:
	_bm.spawn_enemy_bullet(Vector2.ZERO, Vector2.ZERO)
	assert_eq(_bm.active_enemy_bullet_count(), 0, "no stationary orbs")


func test_clear_empties_both_bands() -> void:
	_bm.spawn_player_bullet(0, Vector2.ZERO, Vector2.RIGHT)
	_bm.spawn_enemy_bullet(Vector2.ZERO, Vector2(0.0, 100.0))
	_bm.clear()
	assert_eq(_bm.active_player_bullet_count(), 0)
	assert_eq(_bm.active_enemy_bullet_count(), 0)


# --- collide_enemy_bullets_with_players (CP 1.5) ----------------------------

## In-tree ship (global_position valid) with no input, so its _process is inert.
func _ship_at(at: Vector2) -> Tubbu:
	var tubbu := Tubbu.new()
	tubbu.position = at
	add_child_autofree(tubbu)
	return tubbu


func test_enemy_bullet_kills_an_exposed_player() -> void:
	var player := _ship_at(Vector2(50.0, 0.0))
	_bm.spawn_enemy_bullet(Vector2(52.0, 0.0), Vector2(0.0, 100.0))
	var kills := _bm.collide_enemy_bullets_with_players([player], 10.0)
	assert_eq(kills, 1)
	assert_false(player.is_alive(), "one orb, one death")
	assert_eq(_bm.active_enemy_bullet_count(), 0, "the killing orb is consumed")


func test_enemy_bullet_passes_through_dash_iframes() -> void:
	# The dash rule lives in Tubbu.try_kill; the bullet must honor it and slip by.
	var player := _ship_at(Vector2(50.0, 0.0))
	player._dash.try_dash(Vector2.RIGHT)
	assert_true(player.is_invulnerable(), "sanity: i-frames are up")
	_bm.spawn_enemy_bullet(Vector2(52.0, 0.0), Vector2(0.0, 100.0))
	var kills := _bm.collide_enemy_bullets_with_players([player], 10.0)
	assert_eq(kills, 0, "i-frames shrug it off")
	assert_true(player.is_alive())
	assert_eq(_bm.active_enemy_bullet_count(), 1, "the orb passes through, not consumed")


func test_enemy_bullet_misses_outside_the_radius() -> void:
	var player := _ship_at(Vector2(50.0, 0.0))
	_bm.spawn_enemy_bullet(Vector2(200.0, 0.0), Vector2(0.0, 100.0))
	var kills := _bm.collide_enemy_bullets_with_players([player], 10.0)
	assert_eq(kills, 0)
	assert_true(player.is_alive())
	assert_eq(_bm.active_enemy_bullet_count(), 1, "a miss costs nothing")


func test_enemy_bullet_ignores_a_corpse() -> void:
	var player := _ship_at(Vector2(50.0, 0.0))
	player.try_kill()
	_bm.spawn_enemy_bullet(Vector2(50.0, 0.0), Vector2(0.0, 100.0))
	var kills := _bm.collide_enemy_bullets_with_players([player], 10.0)
	assert_eq(kills, 0, "a dead player can't be killed again")
	assert_eq(_bm.active_enemy_bullet_count(), 1, "and the orb is not consumed")


# --- nearest_enemy_bullet (CP 1.8 near-miss query) --------------------------

func test_nearest_enemy_bullet_none_when_empty() -> void:
	assert_false(_bm.nearest_enemy_bullet(Vector2.ZERO)["found"], "no orbs, no graze")


func test_nearest_enemy_bullet_picks_the_closest() -> void:
	_bm.spawn_enemy_bullet(Vector2(100.0, 0.0), Vector2(0.0, 50.0))
	_bm.spawn_enemy_bullet(Vector2(20.0, 0.0), Vector2(0.0, 50.0))   # closest
	_bm.spawn_enemy_bullet(Vector2(0.0, 60.0), Vector2(50.0, 0.0))
	var near := _bm.nearest_enemy_bullet(Vector2.ZERO)
	assert_true(near["found"])
	assert_eq(near["position"], Vector2(20.0, 0.0))
	assert_almost_eq(near["distance"], 20.0, 0.001)


func test_nearest_enemy_bullet_ignores_the_player_band() -> void:
	# A graze is enemy fire only; the player's own shots must not trigger it.
	_bm.spawn_player_bullet(0, Vector2(5.0, 0.0), Vector2.RIGHT)
	assert_false(_bm.nearest_enemy_bullet(Vector2.ZERO)["found"])
