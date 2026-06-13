class_name SandboxSpawner
extends Node2D
## Continuous chaser spawner for the Phase-1 sandbox (CP 1.4). The real wave
## spawner with telegraphs is CP 2.2; this one only exists so Ludo can dial a
## swarm up and down (debug panel slider) and surf it.
##
## Owns the chaser EnemyPool and the per-frame bullet-vs-chaser pass; chasers
## themselves only steer and contact-kill.

const CHASER_CAPACITY := 200      ## > the 50+ the milestone playtest needs
const MIN_PLAYER_DISTANCE := 380.0  ## no spawns on the player's head
const SPAWN_TRIES := 12           ## rejection samples before settling
const EDGE_MARGIN := 30.0         ## keep spawns off the walls

## Spawns per second; the debug panel slider drives this live.
var spawn_rate := 6.0

# Injected by Game.
var players: Array[Tubbu] = []
var bullet_manager: BulletManager
var palette: PaletteResource
var bounds := Rect2()

var _pool: EnemyPool
var _accumulator := 0.0


func _ready() -> void:
	_pool = EnemyPool.new(_make_chaser, CHASER_CAPACITY)


func _process(delta: float) -> void:
	# Bullets kill chasers: one bullet-major pass per frame (BulletManager owns
	# the loop so its storage stays sealed), then the slots go home.
	var hits := bullet_manager.collide_player_bullets(
		_pool.live_nodes(), Chaser.BULLET_HIT_RADIUS)
	for chaser: Chaser in hits:
		chaser.die()
		_pool.release(chaser)

	if not _any_player_alive():
		return  # death freezes the tide; restart clears it
	_accumulator += delta * spawn_rate
	while _accumulator >= 1.0:
		_accumulator -= 1.0
		_spawn_one()


## Everything off the board (restart).
func clear() -> void:
	for chaser: Chaser in _pool.live_nodes():
		chaser.deactivate()
	_pool.release_all()
	_accumulator = 0.0


func live_count() -> int:
	return _pool.live_count()


func _spawn_one() -> void:
	var chaser: Chaser = _pool.acquire()
	if chaser == null:
		return  # pool saturated: skip — never recycle a live enemy (unfair)
	chaser.activate(_pick_spawn_position())


## Random point in the arena, rejection-sampled to keep MIN_PLAYER_DISTANCE
## from every alive player; if the arena is too crowded to satisfy that, the
## farthest candidate wins (degrade gracefully, never hang).
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


## Pool factory: built once per slot, injected once, lives parked under this
## node between activations.
func _make_chaser() -> Chaser:
	var chaser := Chaser.new()
	chaser.palette = palette
	chaser.players = players
	add_child(chaser)
	return chaser
