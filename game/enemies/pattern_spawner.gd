class_name PatternSpawner
extends Node2D
## Sandbox spawner for Enemy 2, the pattern shooter (CP 1.5). The real wave
## spawner with telegraphs is CP 2.2; this one keeps a small steady population
## of stationary shooters so there is always a pattern to weave, and drives the
## two bullet passes that touch them:
##   - player bullets damage shooters (HP-gated kill)
##   - enemy bullets vs players — the SINGLE global pass, i-frame-safe via
##     Tubbu.try_kill. CP 2.1's run owner will likely absorb that global pass;
##     for the Phase-1 sandbox it lives on the one node that both sources enemy
##     bullets and processes after the players (so it sees fresh positions).

const SHOOTER_COUNT := 2          ## steady population in the sandbox
const SHOOTER_CAPACITY := 8       ## pool headroom
const RESPAWN_DELAY := 2.0        ## s between replacing a killed shooter
const EDGE_MARGIN := 220.0        ## keep shooters off the walls (room to orbit)
const MIN_PLAYER_DISTANCE := 360.0
const SPAWN_TRIES := 12           ## rejection samples before settling

# Injected by Game.
var players: Array[Tubbu] = []
var bullet_manager: BulletManager
var palette: PaletteResource
var bounds := Rect2()
var enabled := true               ## debug panel toggle

var _pool: EnemyPool
var _respawn_timer := 0.0


func _ready() -> void:
	_pool = EnemyPool.new(_make_shooter, SHOOTER_CAPACITY)


func _process(delta: float) -> void:
	# Player bullets damage shooters: one bullet-major pass (BulletManager owns
	# the loop so its storage stays sealed), then dead slots go home.
	var hits := bullet_manager.collide_player_bullets(
			_pool.live_nodes(), PatternShooter.BULLET_HIT_RADIUS)
	for shooter: PatternShooter in hits:
		if shooter.take_hit():
			shooter.die()
			_pool.release(shooter)

	# Enemy bullets vs players: the single global pass. Honors dash i-frames at
	# the one gate (inside Tubbu.try_kill). Harmless while everyone's dead.
	bullet_manager.collide_enemy_bullets_with_players(
			players, Tubbu.HIT_RADIUS + BulletManager.ENEMY_BULLET_RADIUS)

	# Maintain the population (only while someone is alive to threaten).
	if not enabled or not _any_player_alive():
		return
	_respawn_timer = maxf(_respawn_timer - delta, 0.0)
	if _pool.live_count() < SHOOTER_COUNT and _respawn_timer <= 0.0:
		_respawn_timer = RESPAWN_DELAY
		_spawn_one()


## Everything off the board (restart).
func clear() -> void:
	for shooter: PatternShooter in _pool.live_nodes():
		shooter.deactivate()
	_pool.release_all()
	_respawn_timer = 0.0


func live_count() -> int:
	return _pool.live_count()


func _spawn_one() -> void:
	var shooter: PatternShooter = _pool.acquire()
	if shooter == null:
		return  # pool saturated: skip (never recycle a live enemy)
	shooter.activate(_pick_spawn_position())


## Random point inside the wall-margined arena, rejection-sampled to keep
## MIN_PLAYER_DISTANCE from every alive player; the farthest candidate wins if
## the arena is too crowded (degrade gracefully, never hang).
func _pick_spawn_position() -> Vector2:
	var area := bounds.grow(-EDGE_MARGIN)
	var best := area.get_center()
	var best_dist := -1.0
	for _try in SPAWN_TRIES:
		var candidate := Vector2(
				randf_range(area.position.x, area.end.x),
				randf_range(area.position.y, area.end.y))
		var dist := _distance_to_nearest_alive_player(candidate)
		if dist >= MIN_PLAYER_DISTANCE:
			return candidate
		if dist > best_dist:
			best_dist = dist
			best = candidate
	return best


func _distance_to_nearest_alive_player(from: Vector2) -> float:
	var nearest := Chaser.nearest_alive_player(players, from)
	if nearest == null:
		return INF
	return from.distance_to(nearest.global_position)


func _any_player_alive() -> bool:
	for player in players:
		if player.is_alive():
			return true
	return false


## Pool factory: built once per slot, injected once, parked under this node
## between activations.
func _make_shooter() -> PatternShooter:
	var shooter := PatternShooter.new()
	shooter.palette = palette
	shooter.players = players
	shooter.bullet_manager = bullet_manager
	add_child(shooter)
	return shooter
