class_name Burst
extends CPUParticles2D
## One-shot radial particle pop (CP 1.4): enemy deaths, the player death burst,
## near-miss sparks. Color is injected per call (asset rule: skin color for
## Tubbu, palette color for enemies).
##
## Pooled (perf): a finished burst returns to a shared free list instead of
## freeing, so a swarm wipe — many enemies popping the same frame — reuses nodes
## instead of churning a fresh CPUParticles2D allocation + tree insert/free for
## each. `is_instance_valid` guards make the static pool safe across scene
## teardown (a freed node is simply skipped).

const LIFETIME := 0.45
const PARTICLE_SIZE_MIN := 2.0
const PARTICLE_SIZE_MAX := 3.5

## Finished bursts waiting to be reused. Lives for the session; freed nodes are
## filtered out on take.
static var _free: Array[Burst] = []


## Fire-and-forget: configures a pooled (or new) burst under `parent` at `at`,
## emits one explosive pop, and auto-returns to the pool when it finishes.
static func spawn(parent: Node, at: Vector2, color: Color,
		count: int, speed: float) -> void:
	var burst := _take()
	burst.amount = count
	burst.color = color
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.lifetime = LIFETIME
	burst.spread = 180.0  # full radial
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = speed * 0.35
	burst.initial_velocity_max = speed
	burst.damping_min = speed * 0.8  # bleed out instead of flying forever
	burst.damping_max = speed * 1.6
	burst.scale_amount_min = PARTICLE_SIZE_MIN
	burst.scale_amount_max = PARTICLE_SIZE_MAX
	if burst.get_parent() != parent:
		if burst.get_parent() != null:
			burst.get_parent().remove_child(burst)
		parent.add_child(burst)
	burst.global_position = at  # set after parenting, so it's parent-transform-correct
	burst.restart()  # (re)emits the one-shot pop; `finished` returns it to the pool


## A reusable burst from the pool, or a fresh one wired to self-return on finish.
static func _take() -> Burst:
	while not _free.is_empty():
		var pooled: Burst = _free.pop_back()
		if is_instance_valid(pooled):
			return pooled
	var burst := Burst.new()
	burst.finished.connect(func() -> void: _release(burst))
	return burst


static func _release(burst: Burst) -> void:
	burst.emitting = false
	_free.append(burst)
