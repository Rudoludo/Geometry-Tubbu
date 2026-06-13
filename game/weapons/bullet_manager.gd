class_name BulletManager
extends Node2D
## Owns every live projectile: pooled storage, one update loop, one draw pass.
##
## Architecture contract (CP 1.2, load-bearing — keep it honest):
## - Bullets are NOT nodes. Storage is slot-indexed parallel arrays
##   (struct-of-arrays) hidden behind a narrow API: gameplay callers may only
##   use spawn_* / collide_* / clear / counts. The planned CP 3.5 move to
##   MultiMesh rendering is then internal — stable slots map 1:1 to instance
##   indices.
## - Slots are stable for a bullet's lifetime; dead slots go to a free list.
##   On exhaustion the OLDEST live bullet is recycled (lowest spawn seq): fire
##   never stutters, and the oldest shot is the least load-bearing one.
##
## CP 1.5 adds an enemy band beside the player one. The two are separate `_Pool`
## instances (own capacity, own seq) so neither starves the other; the facade
## below keeps the spawning policy, collision and per-band draw style that
## actually differ. Each `_Pool` maps cleanly to one MultiMesh at CP 3.5.

# --- Player base shot (CP 2.4 replaces these with the resolved config) -------
const PLAYER_BULLET_SPEED := 1150.0   ## px/s
const PLAYER_BULLET_TTL := 1.2        ## s safety cull; arena walls cull first
const PLAYER_BULLET_CAPACITY := 256

# --- Enemy bullets (CP 1.5) -------------------------------------------------
## Slow & highly visible per the design's one-hit hard-edge mitigation; speed is
## the shooter's call (it passes a full velocity), so patterns can vary it.
const ENEMY_BULLET_TTL := 8.0         ## s backstop; arena walls cull first
const ENEMY_BULLET_CAPACITY := 512    ## dense patterns + slow bullets accumulate
## Lethal contribution added to the player's tiny hitbox. The visual disc below
## is bigger than this sum is over the body, so bullets can clip the ship's
## wireframe without killing — the grazing window (bullet-hell convention).
const ENEMY_BULLET_RADIUS := 4.0

# --- Player streak rendering (palette-driven; CP 1.6 juices this) ------------
const STREAK_LENGTH := 14.0   ## px tracer tail behind the bullet head
const STREAK_WIDTH := 3.5
const STREAK_ALPHA := 0.55
const CORE_RADIUS := 2.5

# --- Enemy orb rendering ----------------------------------------------------
## Deliberately unlike the player's fast streaks: a slow, round, soft-edged orb
## so an incoming threat is never confused with your own fire (readability rule).
const ENEMY_DRAW_RADIUS := 6.5   ## visual disc; > the hitbox so you can graze
const ENEMY_CORE_RADIUS := 2.5
const ENEMY_HALO_ALPHA := 0.4

## Injected by Game; bullets die on leaving these bounds (TTL is the backstop).
var bounds := Rect2()
## Injected by Game (asset rule: no hard-coded colors in feature code).
var palette: PaletteResource

var _player: _Pool
var _enemy: _Pool
var _was_drawing := false


## A slot-stable SoA bullet pool with a free list. One instance per team; the
## per-team draw/collision differences stay in the facade above.
class _Pool:
	var capacity: int
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	var ttl := PackedFloat32Array()
	var owner := PackedInt32Array()   ## firing player (co-op / scoring); -1 = enemy
	var seq := PackedInt64Array()     ## spawn order, for recycle-the-oldest
	var alive := PackedByteArray()    ## 1 = live, 0 = hole
	var free := PackedInt32Array()    ## stack of dead slots
	var live_count := 0
	var _next_seq := 0

	func _init(cap: int) -> void:
		capacity = cap
		pos.resize(cap)
		vel.resize(cap)
		ttl.resize(cap)
		owner.resize(cap)
		seq.resize(cap)
		alive.resize(cap)
		alive.fill(0)
		for slot in cap:
			free.append(cap - 1 - slot)  # so slot 0 pops first

	func spawn(origin: Vector2, velocity: Vector2, life: float, owner_index: int) -> void:
		var slot := _acquire()
		pos[slot] = origin
		vel[slot] = velocity
		ttl[slot] = life
		owner[slot] = owner_index
		seq[slot] = _next_seq
		_next_seq += 1

	func release(slot: int) -> void:
		alive[slot] = 0
		free.append(slot)
		live_count -= 1

	## Integrate + cull (TTL and, if set, the arena bounds).
	func step(delta: float, world_bounds: Rect2) -> void:
		var bounded := world_bounds.has_area()
		for slot in capacity:
			if alive[slot] == 0:
				continue
			pos[slot] += vel[slot] * delta
			ttl[slot] -= delta
			if ttl[slot] <= 0.0 or (bounded and not world_bounds.has_point(pos[slot])):
				release(slot)

	func clear() -> void:
		for slot in capacity:
			if alive[slot] == 1:
				release(slot)

	func _acquire() -> int:
		if not free.is_empty():
			var slot := free[free.size() - 1]
			free.resize(free.size() - 1)
			alive[slot] = 1
			live_count += 1
			return slot
		# Exhausted (free empty ⟺ every slot live): recycle the oldest. Linear
		# scan is fine — it runs only while saturated, never in steady state.
		var oldest := 0
		var oldest_seq := seq[0]
		for slot in capacity:
			if seq[slot] < oldest_seq:
				oldest_seq = seq[slot]
				oldest = slot
		return oldest


func _ready() -> void:
	# Stored positions are world-space; stay out of any parent transform. Bullets
	# draw above ships and enemies (z below) so an incoming enemy orb is never
	# hidden under your own sprite — non-negotiable in a one-hit game.
	top_level = true
	z_index = 5
	_player = _Pool.new(PLAYER_BULLET_CAPACITY)
	_enemy = _Pool.new(ENEMY_BULLET_CAPACITY)


func _process(delta: float) -> void:
	step(delta)


## The single update loop: integrate, cull, redraw. Public so tests (and a
## future game-state owner) can drive it deterministically without frames.
func step(delta: float) -> void:
	_player.step(delta, bounds)
	_enemy.step(delta, bounds)
	if _live_total() > 0 or _was_drawing:
		queue_redraw()


## Fires one base player shot. `player_index` rides along for kill attribution
## (co-op rule: scoring accepts N players from day one).
func spawn_player_bullet(player_index: int, origin: Vector2, direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return  # no direction, no bullet — never a stationary one
	_player.spawn(origin, direction.normalized() * PLAYER_BULLET_SPEED,
			PLAYER_BULLET_TTL, player_index)


## Fires one enemy bullet (CP 1.5). The shooter passes a full velocity so the
## pattern owns the speed; a zero velocity is a no-op (never a stationary orb).
func spawn_enemy_bullet(origin: Vector2, velocity: Vector2) -> void:
	if velocity == Vector2.ZERO:
		return
	_enemy.spawn(origin, velocity, ENEMY_BULLET_TTL, -1)


func active_player_bullet_count() -> int:
	return _player.live_count


func active_enemy_bullet_count() -> int:
	return _enemy.live_count


## Collides every live player bullet against `targets` (anything with a
## `global_position`) in one bullet-major pass: the first target within
## `hit_radius` of a bullet eats it. A target eats at most one bullet per call
## (it is dead after the first — a corpse must not soak later shots), and one
## bullet kills at most one target (pierce is CP 2.5). Returns the targets hit.
## Callers get nodes back, never slots — storage stays internal (CP 3.5).
func collide_player_bullets(targets: Array, hit_radius: float) -> Array:
	var hit: Array = []
	if _player.live_count == 0 or targets.is_empty():
		return hit
	var remaining := targets.duplicate()
	var radius_sq := hit_radius * hit_radius
	for slot in _player.capacity:
		if _player.alive[slot] == 0:
			continue
		for i in remaining.size():
			var target: Node2D = remaining[i]
			if _player.pos[slot].distance_squared_to(target.global_position) <= radius_sq:
				_player.release(slot)
				hit.append(target)
				remaining.remove_at(i)
				break
		if remaining.is_empty():
			break
	if not hit.is_empty():
		queue_redraw()
	return hit


## Collides every live enemy bullet against the players (CP 1.5). A bullet within
## `hit_radius` of an alive player tries to kill it through Tubbu.try_kill — so
## dash i-frames are honored at the ONE gate (CP 1.4 rule), never re-checked
## here. A bullet that lands a kill is consumed; one shrugged off by i-frames
## passes through (you dashed through it). Returns the number of kills.
func collide_enemy_bullets_with_players(players: Array, hit_radius: float) -> int:
	var kills := 0
	if _enemy.live_count == 0 or players.is_empty():
		return kills
	var radius_sq := hit_radius * hit_radius
	for slot in _enemy.capacity:
		if _enemy.alive[slot] == 0:
			continue
		for player: Tubbu in players:
			if player == null or not player.is_alive():
				continue
			if _enemy.pos[slot].distance_squared_to(player.global_position) > radius_sq:
				continue
			if player.try_kill():
				_enemy.release(slot)
				kills += 1
				break  # bullet consumed; stop scanning players for it
			# else: i-frames shrugged it off — keep the bullet, keep scanning
	if kills > 0:
		queue_redraw()
	return kills


## Nearest live enemy bullet to `point`, for Tubbu's near-miss graze check
## (CP 1.8). Read-only — it consumes nothing. Returns {"found": false} or
## {"found": true, "position": Vector2, "distance": float}. O(n) over the enemy
## band; cheap with the player count this game runs.
func nearest_enemy_bullet(point: Vector2) -> Dictionary:
	var best_sq := INF
	var best := Vector2.ZERO
	for slot in _enemy.capacity:
		if _enemy.alive[slot] == 0:
			continue
		var d_sq := _enemy.pos[slot].distance_squared_to(point)
		if d_sq < best_sq:
			best_sq = d_sq
			best = _enemy.pos[slot]
	if best_sq == INF:
		return {"found": false}
	return {"found": true, "position": best, "distance": sqrt(best_sq)}


## Despawns everything in both bands (room transitions, run resets).
func clear() -> void:
	_player.clear()
	_enemy.clear()
	queue_redraw()


## Test/debug introspection only — NOT part of the gameplay contract, so it
## may change freely when storage moves to MultiMesh (CP 3.5).
func debug_player_bullets() -> Array[Dictionary]:
	return _debug_dump(_player)


func debug_enemy_bullets() -> Array[Dictionary]:
	return _debug_dump(_enemy)


func _debug_dump(pool: _Pool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in pool.capacity:
		if pool.alive[slot] == 1:
			out.append({
				"position": pool.pos[slot],
				"velocity": pool.vel[slot],
				"ttl": pool.ttl[slot],
				"owner_index": pool.owner[slot],
			})
	return out


func _live_total() -> int:
	return _player.live_count + _enemy.live_count


func _draw() -> void:
	_was_drawing = _live_total() > 0
	if palette == null or not _was_drawing:
		return
	_draw_player_streaks()
	_draw_enemy_orbs()


func _draw_player_streaks() -> void:
	if _player.live_count == 0:
		return
	var color := palette.player_bullet_color
	var tail_color := Color(color, STREAK_ALPHA)
	for slot in _player.capacity:
		if _player.alive[slot] == 0:
			continue
		var head := _player.pos[slot]
		var tail := head - _player.vel[slot].normalized() * STREAK_LENGTH
		# Tracer streak + bright core: reads as direction at a glance and the
		# overbright palette color feeds the HDR bloom once CP 1.6 lands.
		draw_line(tail, head, tail_color, STREAK_WIDTH, true)
		draw_circle(head, CORE_RADIUS, color, true, -1.0, true)


func _draw_enemy_orbs() -> void:
	if _enemy.live_count == 0:
		return
	var color := palette.enemy_bullet_color
	var halo := Color(color, ENEMY_HALO_ALPHA)
	for slot in _enemy.capacity:
		if _enemy.alive[slot] == 0:
			continue
		var head := _enemy.pos[slot]
		# Soft halo + solid core: a glowing orb you can read and graze, distinct
		# from the player's streaks.
		draw_circle(head, ENEMY_DRAW_RADIUS, halo, true, -1.0, true)
		draw_circle(head, ENEMY_CORE_RADIUS, color, true, -1.0, true)
