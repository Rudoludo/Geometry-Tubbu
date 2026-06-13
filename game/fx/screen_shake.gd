class_name ScreenShake
extends RefCounted
## Trauma-based screen shake (CP 1.6). Sources add *trauma* (0..1); it decays
## linearly, and the applied shake scales with trauma SQUARED — so a small bump
## barely moves the view while a big one slams (the standard "Math for Game
## Programmers: Juicing Your Cameras" model). Squaring also means stacked swarm
## kills don't pile into a nauseating constant rattle that would hide bullets
## (readability rule).
##
## Pure and owner-ticked (like DashAbility): this holds only the 0..1 trauma
## curve, so it is unit-testable without a camera. The ArenaCamera maps the
## eased magnitude onto pixels/radians and scales it by the player's setting.

const DECAY := 3.0   ## trauma drained per second — fast, so the view settles quickly

var _trauma := 0.0


## A shake source (a kill, a death). Clamped so it can never overdrive.
func add(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Drain the trauma. Call once per frame, before reading shake().
func tick(delta: float) -> void:
	_trauma = maxf(_trauma - DECAY * delta, 0.0)


## The eased 0..1 magnitude the camera applies (trauma^2).
func shake() -> float:
	return _trauma * _trauma


func has_shake() -> bool:
	return _trauma > 0.0


## Test/debug introspection.
func trauma() -> float:
	return _trauma
