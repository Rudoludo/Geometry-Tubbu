class_name DashAbility
extends RefCounted
## The survival verb (CP 1.3): READY -> DASHING -> cooldown drains -> READY.
## Pure timer logic, owner-ticked like PlayerInput/Weapon; unit-tested.
##
## I-frames run on their own clock, deliberately separate from the dash
## impulse window: CP 2.7's "longer i-frames" upgrade then changes a number,
## not the state machine. CP 2.7's cooldown-reduction upgrade hits COOLDOWN
## the same way.

const DASH_SPEED := 1500.0    ## px/s; movement control is suspended meanwhile
const DASH_DURATION := 0.16   ## s of impulse
const I_FRAMES := 0.16        ## s of invulnerability from dash start
const COOLDOWN := 1.0         ## s from dash start to the next dash (~1 s per design)

## Live feel knobs (CP 1.8 tuning panel), seeded from the consts above. CP 2.7's
## cooldown-reduction / longer-i-frames upgrades land on these same fields.
## Preserved across revive (Tubbu resets the clocks, not the instance).
var dash_speed := DASH_SPEED
var dash_duration := DASH_DURATION
var i_frames := I_FRAMES
var cooldown := COOLDOWN

var _dash_left := 0.0
var _iframes_left := 0.0
var _cooldown_left := 0.0
var _direction := Vector2.ZERO


## Drains all clocks. Call once per frame, before reads.
func tick(delta: float) -> void:
	_dash_left = maxf(_dash_left - delta, 0.0)
	_iframes_left = maxf(_iframes_left - delta, 0.0)
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


## Starts a dash if off cooldown and given a direction; reports whether it
## started. The caller picks the direction (move vector, or its fallback).
func try_dash(direction: Vector2) -> bool:
	if direction == Vector2.ZERO or _cooldown_left > 0.0:
		return false
	_direction = direction.normalized()
	_dash_left = dash_duration
	_iframes_left = i_frames
	_cooldown_left = cooldown
	return true


func is_dashing() -> bool:
	return _dash_left > 0.0


## The hitbox-off window. CP 1.4's contact kill (and CP 1.5's bullets) must
## check this before killing the owner.
func is_invulnerable() -> bool:
	return _iframes_left > 0.0


func is_ready() -> bool:
	return _cooldown_left <= 0.0


func direction() -> Vector2:
	return _direction


## 0 right after a dash, 1 when ready again — drives the no-HUD ship-glow
## refill feedback.
func cooldown_fraction() -> float:
	if cooldown <= 0.0:
		return 1.0
	return 1.0 - _cooldown_left / cooldown


## Clears the dash/i-frame/cooldown clocks without dropping tuning — the revive
## reset (CP 1.8), so live dash tweaks survive death/restart.
func reset() -> void:
	_dash_left = 0.0
	_iframes_left = 0.0
	_cooldown_left = 0.0
	_direction = Vector2.ZERO
