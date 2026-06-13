class_name EnemyPool
extends RefCounted
## Reuse pool for node-based enemies (CP 1.4).
##
## Enemies are nodes (unlike bullets): each type carries its own behavior and
## the roster grows folder-per-type, so SoA storage buys nothing here. The pool
## only manages identity — nodes are built lazily by the injected factory up to
## capacity, released nodes are handed out again, and nothing is ever freed.
## Activation/deactivation (visibility, processing) is the caller's job; the
## pool stays dumb so it is testable with bare nodes.
##
## On exhaustion acquire() returns null and the spawn is SKIPPED — the opposite
## of BulletManager's recycle-the-oldest: dropping a shot stutters the gun, but
## teleporting a live enemy under the player is an unfair death in a one-hit
## game.

var _factory: Callable
var _capacity: int
var _free: Array[Node2D] = []
var _live: Array[Node2D] = []


func _init(factory: Callable, capacity: int) -> void:
	_factory = factory
	_capacity = capacity


## A node ready to activate, or null when all `capacity` nodes are live.
func acquire() -> Node2D:
	var node: Node2D
	if not _free.is_empty():
		node = _free.pop_back()
	elif _live.size() < _capacity:
		node = _factory.call()
	else:
		return null
	_live.append(node)
	return node


## Returns a live node to the pool. The caller deactivates it first.
func release(node: Node2D) -> void:
	var at := _live.find(node)
	if at == -1:
		push_warning("EnemyPool: released a node it doesn't own — ignored")
		return
	_live.remove_at(at)
	_free.append(node)


## Everything back to the pool at once (restart, room clear).
func release_all() -> void:
	_free.append_array(_live)
	_live.clear()


## Snapshot of the live nodes — a copy, safe to release() against while iterating.
func live_nodes() -> Array[Node2D]:
	return _live.duplicate()


func live_count() -> int:
	return _live.size()
