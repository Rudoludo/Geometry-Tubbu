class_name Chaser
extends Node2D
## Enemy 1 (CP 1.4): the contact-swarm grunt. Steers toward the nearest alive
## player with a sinusoidal wobble and a per-instance speed roll, so a crowd
## reads as an organic swarm instead of a single stacked blob. Kills on touch
## (one-hit game; dash i-frames are honored inside Tubbu.try_kill).
##
## Pooled: the SandboxSpawner owns the EnemyPool and calls activate() /
## deactivate(); this node never frees itself. Bullet hits are resolved by the
## spawner through BulletManager.collide_player_bullets — the chaser only
## handles steering and contact.

# --- Tuning (CP 1.8 lifts feel consts into the debug panel) -----------------
const MAX_SPEED := 250.0          ## px/s before the per-instance roll
const ACCELERATION := 1400.0      ## px/s^2 — finite, so pursuit curves
const SPEED_ROLL_MIN := 0.85      ## per-instance speed spread breaks up clumps
const SPEED_ROLL_MAX := 1.1
const JITTER_ANGLE := 0.45        ## rad of sinusoidal heading wobble
const JITTER_FREQ_MIN := 4.0      ## Hz-ish wobble rate, rolled per instance
const JITTER_FREQ_MAX := 7.0
const CONTACT_RADIUS := 9.0       ## body reach for the contact kill
const BULLET_HIT_RADIUS := 12.0   ## generous vs the visual — favors the shooter
const POP_PARTICLES := 12
const POP_SPEED := 260.0

## Local-space wireframe arrow-diamond, +X = facing. Shape is per-enemy-type
## identity (silhouette rule); the color comes from the palette (asset rule).
const BODY_POINTS: PackedVector2Array = [
	Vector2(14.0, 0.0), Vector2(0.0, 9.0), Vector2(-9.0, 0.0), Vector2(0.0, -9.0),
]

# Injected once by the spawner's factory.
var palette: PaletteResource
var players: Array[Tubbu] = []

var velocity := Vector2.ZERO

var _speed_roll := 1.0
var _jitter_freq := 0.0
var _jitter_phase := 0.0
var _time := 0.0


## Brings a pooled instance back into play at `at`.
func activate(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	_speed_roll = randf_range(SPEED_ROLL_MIN, SPEED_ROLL_MAX)
	_jitter_freq = randf_range(JITTER_FREQ_MIN, JITTER_FREQ_MAX)
	_jitter_phase = randf() * TAU
	_time = 0.0
	visible = true
	set_process(true)


## Out of play; the spawner releases the slot back to the pool.
func deactivate() -> void:
	visible = false
	set_process(false)


func _ready() -> void:
	deactivate()  # born pooled; activate() puts it in play


func _process(delta: float) -> void:
	_time += delta
	var target := nearest_alive_player(players, global_position)
	if target == null:
		# Nobody to chase (player dead, restart pending): drift to a stop.
		velocity = velocity.move_toward(Vector2.ZERO, ACCELERATION * delta)
	else:
		var to_target := target.global_position - global_position
		var wobble := sin(_time * _jitter_freq + _jitter_phase) * JITTER_ANGLE
		var desired := to_target.normalized().rotated(wobble) \
				* MAX_SPEED * _speed_roll
		velocity = velocity.move_toward(desired, ACCELERATION * delta)
	position += velocity * delta
	if velocity != Vector2.ZERO:
		rotation = velocity.angle()
	if target != null and global_position.distance_to(target.global_position) \
			<= CONTACT_RADIUS + Tubbu.HIT_RADIUS:
		target.try_kill()


## Bullet death: pop and go dormant. The spawner returns the pool slot.
func die() -> void:
	if is_inside_tree() and palette != null:
		Burst.spawn(get_parent(), global_position, palette.enemy_color,
				POP_PARTICLES, POP_SPEED)
	EventBus.enemy_killed.emit(global_position)  # juice + (later) score/audio
	deactivate()


## Pure target selection: closest player still alive, or null. Static so the
## swarm logic is unit-testable without frames.
static func nearest_alive_player(candidates: Array[Tubbu], from: Vector2) -> Tubbu:
	var best: Tubbu = null
	var best_dist_sq := INF
	for player in candidates:
		if player == null or not player.is_alive():
			continue
		var dist_sq := from.distance_squared_to(player.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = player
	return best


func _draw() -> void:
	if palette == null:
		return
	var outline := BODY_POINTS.duplicate()
	outline.append(outline[0])  # close the loop
	# Same double-line trick as the arena walls: bright edge over a dim echo
	# reads as a neon tube once the bloom (CP 1.6) lands.
	draw_polyline(outline, palette.enemy_color, 2.0, true)
	var inner := Transform2D(0.0, Vector2.ZERO).scaled(Vector2(0.55, 0.55)) \
			* outline
	draw_polyline(inner, palette.enemy_color * 0.45, 1.0, true)
