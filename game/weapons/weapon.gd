class_name Weapon
extends RefCounted
## One player's gun: fire cadence + muzzle geometry for the base shot.
##
## CP 1.2 hard-codes the base-shot numbers as consts. CP 2.4 is the planned
## replacement point: base stats -> modifier stack -> resolved shot config,
## with this class consuming the result. Owned and ticked by the player ship,
## mirroring the PlayerInput pattern (RefCounted, owner-driven, pure-testable).

const FIRE_RATE := 9.0        ## shots/s
const MUZZLE_OFFSET := 22.0   ## px ahead of the ship centre, along aim

var _cooldown := 0.0


## Advances the fire timer; returns how many shots are due this frame (0 most
## frames; >1 only if a frame outlasts the fire period). While not firing the
## timer keeps draining but clamps at zero, so shots can't be banked and the
## first shot after re-engaging is immediate — tap-fire feels instant.
func tick(delta: float, firing: bool) -> int:
	_cooldown -= delta
	if not firing:
		_cooldown = maxf(_cooldown, 0.0)
		return 0
	var shots := 0
	while _cooldown <= 0.0:
		shots += 1
		_cooldown += 1.0 / FIRE_RATE
	return shots
