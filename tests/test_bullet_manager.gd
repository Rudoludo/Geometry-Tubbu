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
