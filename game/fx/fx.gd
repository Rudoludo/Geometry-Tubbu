class_name Fx
extends RefCounted
## Particle-effect library (CP 1.6). Builds configured CPUParticles2D emitters;
## the caller owns them (adds to the tree, drives transform + emitting). The
## one-shot radial pops (enemy death, player death) live in [Burst] — these are
## the *persistent* streams that follow the ship.
##
## Colors are passed in, never hard-coded (asset rule): the muzzle takes the
## bullet color from the palette so it reads as the gun firing; the dash trail
## takes the ship's trail color from the skin. CP 4.2 swaps these for authored
## assets without touching gameplay code.

## Muzzle flash: a tight forward spray along the emitter's local +X, so the
## caller just rotates the node to the aim direction and toggles `emitting`.
## World-space (local_coords off) so sparks trail off the moving muzzle.
static func make_muzzle(color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.local_coords = false
	p.amount = 16
	p.lifetime = 0.12
	p.direction = Vector2.RIGHT
	p.spread = 12.0
	p.initial_velocity_min = 240.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2.ZERO
	p.damping_min = 600.0   # bleed out fast — a flash, not a stream
	p.damping_max = 900.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	return p


## Dash trail: a slow, soft radial puff left behind while dashing. World-space
## so the cloud stays put as the ship rockets away — the afterimage smear.
static func make_dash_trail(color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.local_coords = false
	p.amount = 24
	p.lifetime = 0.35
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2.ZERO
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	return p
