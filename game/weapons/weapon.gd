class_name Weapon
extends RefCounted
## One player's gun: fire cadence + muzzle geometry for the base shot.
##
## CP 1.2 hard-codes the base-shot numbers as consts. CP 2.4 is the planned
## replacement point: base stats -> modifier stack -> resolved shot config,
## with this class consuming the result. Owned and ticked by the player ship,
## mirroring the PlayerInput pattern (RefCounted, owner-driven, pure-testable).

const FIRE_RATE := 9.0        ## shots/s (default; CP 1.8 makes it live-tunable)
const MUZZLE_OFFSET := 22.0   ## px ahead of the ship centre, along aim

## Live feel knob (CP 1.8 tuning panel), seeded from the default. Preserved
## across revive (Tubbu resets the timer, not the instance).
var fire_rate := FIRE_RATE

var _cooldown := 0.0


## Advances the fire timer; returns how many shots are due this frame (0 most
## frames; >1 only if a frame outlasts the fire period). While not firing the
## timer keeps draining but clamps at zero, so shots can't be banked and the
## first shot after re-engaging is immediate — tap-fire feels instant.
func tick(delta: float, firing: bool) -> int:
	_cooldown -= delta
	if not firing or fire_rate <= 0.0:
		_cooldown = maxf(_cooldown, 0.0)
		return 0
	var shots := 0
	var period := 1.0 / fire_rate
	while _cooldown <= 0.0:
		shots += 1
		_cooldown += period
	return shots


## Clears the cadence timer without dropping tuning — the revive reset (CP 1.8),
## so a live fire-rate tweak survives death/restart.
func reset() -> void:
	_cooldown = 0.0
