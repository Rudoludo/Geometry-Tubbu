class_name Burst
extends CPUParticles2D
## One-shot radial particle pop (CP 1.4): enemy deaths and the player death
## burst, until the CP 1.6 juice pass builds the real particle library.
## Color is injected per call (asset rule: skin color for Tubbu, palette color
## for enemies); the node frees itself when the burst finishes.

const LIFETIME := 0.45
const PARTICLE_SIZE_MIN := 2.0
const PARTICLE_SIZE_MAX := 3.5


## Fire-and-forget: builds, parents, emits, self-frees.
static func spawn(parent: Node, at: Vector2, color: Color,
		count: int, speed: float) -> void:
	var burst := Burst.new()
	burst.position = at
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = count
	burst.lifetime = LIFETIME
	burst.spread = 180.0  # full radial
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = speed * 0.35
	burst.initial_velocity_max = speed
	burst.damping_min = speed * 0.8  # bleed out instead of flying forever
	burst.damping_max = speed * 1.6
	burst.scale_amount_min = PARTICLE_SIZE_MIN
	burst.scale_amount_max = PARTICLE_SIZE_MAX
	burst.color = color
	burst.finished.connect(burst.queue_free)
	parent.add_child(burst)
