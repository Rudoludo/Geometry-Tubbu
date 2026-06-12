class_name BulletManager
extends Node2D
## Owns every live projectile: pooled storage, one update loop, one draw pass.
##
## Architecture contract (CP 1.2, load-bearing — keep it honest):
## - Bullets are NOT nodes. Storage is slot-indexed parallel arrays
##   (struct-of-arrays) hidden behind a narrow API: gameplay callers may only
##   use spawn_* / clear / counts. The planned CP 3.5 move to MultiMesh
##   rendering is then internal — stable slots map 1:1 to instance indices.
## - Slots are stable for a bullet's lifetime; dead slots go to a free list.
##   On exhaustion the OLDEST live bullet is recycled (lowest spawn seq): the
##   gun never stutters, and the oldest shot is the least load-bearing one.
## - CP 1.5 adds the enemy pool beside the player one (separate capacity and
##   palette entry); CP 2.4 swaps the shot consts for resolved shot configs.

# --- Base shot tuning (CP 2.4 replaces these with the resolved config) ------
const PLAYER_BULLET_SPEED := 1150.0   ## px/s
const PLAYER_BULLET_TTL := 1.2        ## s safety cull; arena walls cull first
const PLAYER_BULLET_CAPACITY := 256

# --- Placeholder rendering (palette-driven; CP 1.6 juices this) -------------
const STREAK_LENGTH := 14.0   ## px tracer tail behind the bullet head
const STREAK_WIDTH := 3.5
const STREAK_ALPHA := 0.55
const CORE_RADIUS := 2.5

## Injected by Game; bullets die on leaving these bounds (TTL is the backstop).
var bounds := Rect2()
## Injected by Game (asset rule: no hard-coded colors in feature code).
var palette: PaletteResource

# Slot-indexed parallel arrays; _alive marks holes, _seq orders by spawn age.
var _pos: PackedVector2Array
var _vel: PackedVector2Array
var _ttl: PackedFloat32Array
var _owner_index: PackedInt32Array  # firing player (co-op / scoring rule)
var _seq: PackedInt64Array
var _alive: PackedByteArray
var _free: PackedInt32Array  # stack of dead slots
var _live_count := 0
var _next_seq := 0
var _was_drawing := false


func _ready() -> void:
	# Stored positions are world-space; stay out of any parent transform.
	top_level = true
	_pos.resize(PLAYER_BULLET_CAPACITY)
	_vel.resize(PLAYER_BULLET_CAPACITY)
	_ttl.resize(PLAYER_BULLET_CAPACITY)
	_owner_index.resize(PLAYER_BULLET_CAPACITY)
	_seq.resize(PLAYER_BULLET_CAPACITY)
	_alive.resize(PLAYER_BULLET_CAPACITY)
	_alive.fill(0)
	for slot in PLAYER_BULLET_CAPACITY:
		_free.append(PLAYER_BULLET_CAPACITY - 1 - slot)  # so slot 0 pops first


func _process(delta: float) -> void:
	step(delta)


## The single update loop: integrate, cull, redraw. Public so tests (and a
## future game-state owner) can drive it deterministically without frames.
func step(delta: float) -> void:
	for slot in PLAYER_BULLET_CAPACITY:
		if _alive[slot] == 0:
			continue
		_pos[slot] += _vel[slot] * delta
		_ttl[slot] -= delta
		if _ttl[slot] <= 0.0 or (bounds.has_area() and not bounds.has_point(_pos[slot])):
			_release(slot)
	if _live_count > 0 or _was_drawing:
		queue_redraw()


## Fires one base shot. `player_index` rides along for kill attribution
## (co-op rule: scoring accepts N players from day one).
func spawn_player_bullet(player_index: int, origin: Vector2, direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return  # no direction, no bullet — never a stationary one
	var slot := _acquire_slot()
	_pos[slot] = origin
	_vel[slot] = direction.normalized() * PLAYER_BULLET_SPEED
	_ttl[slot] = PLAYER_BULLET_TTL
	_owner_index[slot] = player_index
	_seq[slot] = _next_seq
	_next_seq += 1


func active_player_bullet_count() -> int:
	return _live_count


## Despawns everything (room transitions, run resets).
func clear() -> void:
	for slot in PLAYER_BULLET_CAPACITY:
		if _alive[slot] == 1:
			_release(slot)
	queue_redraw()


## Test/debug introspection only — NOT part of the gameplay contract, so it
## may change freely when storage moves to MultiMesh (CP 3.5).
func debug_player_bullets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in PLAYER_BULLET_CAPACITY:
		if _alive[slot] == 1:
			out.append({
				"position": _pos[slot],
				"velocity": _vel[slot],
				"ttl": _ttl[slot],
				"owner_index": _owner_index[slot],
			})
	return out


func _acquire_slot() -> int:
	if not _free.is_empty():
		var slot := _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
		_alive[slot] = 1
		_live_count += 1
		return slot
	# Exhausted: recycle the oldest live bullet. Linear scan is fine — this
	# runs only while the pool is saturated, never in the steady state.
	var oldest_slot := 0
	var oldest_seq := _seq[0]
	for slot in PLAYER_BULLET_CAPACITY:
		if _alive[slot] == 1 and _seq[slot] < oldest_seq:
			oldest_seq = _seq[slot]
			oldest_slot = slot
	return oldest_slot


func _release(slot: int) -> void:
	_alive[slot] = 0
	_free.append(slot)
	_live_count -= 1


func _draw() -> void:
	_was_drawing = _live_count > 0
	if palette == null or _live_count == 0:
		return
	var color := palette.player_bullet_color
	var tail_color := Color(color, STREAK_ALPHA)
	for slot in PLAYER_BULLET_CAPACITY:
		if _alive[slot] == 0:
			continue
		var head := _pos[slot]
		var tail := head - _vel[slot].normalized() * STREAK_LENGTH
		# Tracer streak + bright core: reads as direction at a glance and the
		# overbright palette color feeds the HDR bloom once CP 1.6 lands.
		draw_line(tail, head, tail_color, STREAK_WIDTH, true)
		draw_circle(head, CORE_RADIUS, color, true, -1.0, true)
