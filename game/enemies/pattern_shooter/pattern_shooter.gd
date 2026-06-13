class_name PatternShooter
extends Node2D
## Enemy 2 (CP 1.5): the bullet-hell half of the threat mix. A stationary
## hexagonal emitter that layers two choreographed patterns through the shared
## BulletPattern helper — a slow rotating ring (dodge terrain) and an aimed
## burst at the nearest player (pressure to keep moving). Slow, highly visible
## bullets per the design's one-hit hard-edge mitigation.
##
## Pooled exactly like the chaser: the PatternSpawner owns the EnemyPool and
## calls activate() / deactivate(); this node never frees itself. Player bullets
## are resolved by the spawner through BulletManager.collide_player_bullets —
## the shooter only chooses patterns and takes hits.

# --- Tuning (CP 1.8 lifts feel consts into the debug panel) -----------------
const MAX_HP := 8                 ## survives long enough to be a pattern, not a snipe
const BULLET_HIT_RADIUS := 18.0   ## generous vs the body; > the per-frame bullet step
const MUZZLE_OFFSET := 24.0       ## bullets leave the rim, never the player-kill radius

const RING_COUNT := 12            ## bullets per ring volley (issue #2: denser)
const RING_INTERVAL := 1.5        ## s between rings
const RING_PHASE_STEP := 0.32     ## rad each ring rotates — the readable spiral
const RING_BULLET_SPEED := 230.0  ## px/s — slow & visible

const BURST_COUNT := 4            ## bullets per aimed burst (issue #2: denser)
const BURST_SPREAD := 0.42        ## rad fan width (~24 deg)
const BURST_INTERVAL := 2.5       ## s between bursts
const BURST_BULLET_SPEED := 320.0 ## px/s — the aimed shot presses harder

const BODY_RADIUS := 20.0         ## hexagon silhouette (distinct from the chaser diamond)
const SPIN_SPEED := 0.6           ## rad/s cosmetic turret spin
const POP_PARTICLES := 18
const POP_SPEED := 320.0

# Injected once by the spawner's factory.
var palette: PaletteResource
var players: Array[Tubbu] = []
var bullet_manager: BulletManager

var _hp := MAX_HP
var _ring_timer := 0.0
var _burst_timer := 0.0
var _ring_phase := 0.0


## Brings a pooled instance back into play at `at`. Timers start at a random
## offset so a crowd of shooters never volleys in unison (readability).
func activate(at: Vector2) -> void:
	position = at
	_hp = MAX_HP
	_ring_timer = randf() * RING_INTERVAL
	_burst_timer = randf() * BURST_INTERVAL
	_ring_phase = randf() * TAU
	rotation = 0.0
	visible = true
	set_process(true)


## Out of play; the spawner releases the slot back to the pool.
func deactivate() -> void:
	visible = false
	set_process(false)


func _ready() -> void:
	deactivate()  # born pooled; activate() puts it in play


func _process(delta: float) -> void:
	rotation += SPIN_SPEED * delta  # cosmetic spin (node transform; no redraw needed)
	var target := Chaser.nearest_alive_player(players, global_position)
	if target == null:
		return  # nobody to threaten — hold fire (death freezes the board)
	_ring_timer -= delta
	if _ring_timer <= 0.0:
		_ring_timer += RING_INTERVAL
		_fire_ring()
	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_timer += BURST_INTERVAL
		_fire_burst(target)


## Takes one bullet of damage. Returns true once dead (HP depleted).
func take_hit() -> bool:
	_hp -= 1
	return _hp <= 0


## Bullet death: pop and go dormant. The spawner returns the pool slot.
func die() -> void:
	if is_inside_tree() and palette != null:
		Burst.spawn(get_parent(), global_position, palette.enemy_color,
				POP_PARTICLES, POP_SPEED)
	EventBus.enemy_killed.emit(global_position)  # juice + (later) score/audio
	deactivate()


func _fire_ring() -> void:
	if bullet_manager == null:
		return
	_ring_phase = wrapf(_ring_phase + RING_PHASE_STEP, 0.0, TAU)
	for dir in BulletPattern.ring(RING_COUNT, _ring_phase):
		bullet_manager.spawn_enemy_bullet(
				global_position + dir * MUZZLE_OFFSET, dir * RING_BULLET_SPEED)


func _fire_burst(target: Tubbu) -> void:
	if bullet_manager == null:
		return
	var aim := target.global_position - global_position
	for dir in BulletPattern.aimed_burst(aim, BURST_COUNT, BURST_SPREAD):
		bullet_manager.spawn_enemy_bullet(
				global_position + dir * MUZZLE_OFFSET, dir * BURST_BULLET_SPEED)


func _draw() -> void:
	if palette == null:
		return
	var outline := PackedVector2Array()
	for i in 6:
		outline.append(Vector2.from_angle(TAU * i / 6.0) * BODY_RADIUS)
	outline.append(outline[0])  # close the loop
	# Same double-line neon trick as the arena/chaser: bright edge over a dim
	# echo, plus a core dot that reads as a charged emitter once bloom (CP 1.6)
	# lands. Color from the palette (asset rule); shape is the type's identity.
	draw_polyline(outline, palette.enemy_color, 2.0, true)
	var inner := PackedVector2Array()
	for point in outline:
		inner.append(point * 0.5)
	draw_polyline(inner, palette.enemy_color * 0.45, 1.0, true)
	draw_circle(Vector2.ZERO, 3.0, palette.enemy_color, true, -1.0, true)
