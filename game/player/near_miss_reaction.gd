class_name NearMissReaction
extends RefCounted
## Tubbu's near-miss flinch (CP 1.8). A graze — an enemy bullet skimming past
## within the graze band but beyond the lethal radius — triggers a brief body
## flinch (a brightness + scale spark) that the ship reads off `intensity()`.
## Pure and owner-ticked like DashAbility, so the clocks are unit-tested.
##
## A cooldown gates re-triggers, so a wake of fire *pulses* the flinch instead
## of strobing it every frame; `closeness` (1 = right at the kill edge) scales
## how hard Tubbu reacts. The design's "slowdown shimmer" is rendered as this
## visual flinch, not an actual time-slow: a one-hit bullet-hell must never slow
## the player's own reaction window on a near-miss (readability/fairness rule),
## and an explicit micro-slowmo can be added as a tuning knob if Ludo asks.

const FLINCH_DURATION := 0.18  ## s a flinch takes to fade
const COOLDOWN := 0.16         ## s minimum between flinch triggers

var _flinch_left := 0.0
var _cooldown_left := 0.0
var _peak := 0.0


## Drain the clocks. Call once per frame, before the reads.
func tick(delta: float) -> void:
	_flinch_left = maxf(_flinch_left - delta, 0.0)
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


## Register a graze; `closeness` 0..1 (1 = at the kill edge). Returns whether a
## fresh flinch fired, so the caller can spawn the one-shot spark exactly once.
func graze(closeness: float) -> bool:
	if _cooldown_left > 0.0:
		return false
	_peak = clampf(closeness, 0.0, 1.0)
	_flinch_left = FLINCH_DURATION
	_cooldown_left = COOLDOWN
	return true


## 0..1 flinch strength: the trigger's peak, decaying over the flinch window.
func intensity() -> float:
	if _flinch_left <= 0.0:
		return 0.0
	return _peak * (_flinch_left / FLINCH_DURATION)


func is_flinching() -> bool:
	return _flinch_left > 0.0
