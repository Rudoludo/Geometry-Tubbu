extends GutTest
## EnemyPool (CP 1.4): identity reuse across enemy deaths — the exit-criteria
## test. Built lazily to capacity, never freed, never grown; exhaustion skips
## (returns null) instead of recycling a live enemy (contrast: BulletManager).

const CAPACITY := 3

## Every node the factory ever built — proves reuse by counting constructions.
var _made: Array[Node2D] = []
var _pool: EnemyPool


func before_each() -> void:
	_made.clear()
	_pool = EnemyPool.new(_build_node, CAPACITY)


func _build_node() -> Node2D:
	var node := Node2D.new()
	autofree(node)
	_made.append(node)
	return node


func test_acquire_builds_lazily_up_to_capacity() -> void:
	var first := _pool.acquire()
	assert_not_null(first)
	assert_eq(_made.size(), 1, "built on demand, not up front")
	assert_not_null(_pool.acquire())
	assert_not_null(_pool.acquire())
	assert_null(_pool.acquire(), "saturated pool skips the spawn")
	assert_eq(_made.size(), CAPACITY, "never builds past capacity")


func test_release_then_acquire_reuses_the_same_instance() -> void:
	# Pool reuse across deaths: the dead chaser's node IS the next spawn.
	var first := _pool.acquire()
	_pool.release(first)
	assert_same(_pool.acquire(), first, "the released node comes back")
	assert_eq(_made.size(), 1, "reuse builds nothing new")


func test_release_all_recycles_everything() -> void:
	for _i in CAPACITY:
		_pool.acquire()
	_pool.release_all()
	assert_eq(_pool.live_count(), 0)
	for _i in CAPACITY:
		assert_not_null(_pool.acquire(), "a wiped pool refills fully")
	assert_eq(_made.size(), CAPACITY, "restart wave reuses every node")


func test_live_count_tracks_acquire_and_release() -> void:
	var node := _pool.acquire()
	_pool.acquire()
	assert_eq(_pool.live_count(), 2)
	_pool.release(node)
	assert_eq(_pool.live_count(), 1)


func test_releasing_a_foreign_node_is_ignored() -> void:
	_pool.acquire()
	var stranger: Node2D = autofree(Node2D.new())
	_pool.release(stranger)
	assert_eq(_pool.live_count(), 1, "foreign node can't corrupt the pool")
	# The stranger must not enter the free list either: the next acquires are
	# fresh builds, never the stranger.
	var second := _pool.acquire()
	var third := _pool.acquire()
	assert_true(second != stranger and third != stranger,
		"the stranger never enters circulation")
