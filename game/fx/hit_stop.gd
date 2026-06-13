class_name HitStop
extends Node
## Brief time-freeze on impactful kills (CP 1.6) — the crunch that sells a hit.
## Drops Engine.time_scale to near-zero for a few real milliseconds, then
## restores it. Listens on EventBus: a tap per enemy kill (cooldown-gated so a
## 50-kill swarm frame doesn't strobe into a slideshow) and a longer freeze on
## player death.
##
## Settings-scaled (SettingsStore.hitstop_intensity): 1.0 = full, 0 = off — the
## "all intensities behind SettingsStore" rule. The freeze runs on REAL time
## (Time.get_ticks_usec, immune to the scaled clock it just set), so it always
## thaws even though it scaled time itself to a crawl.

const KILL_DURATION := 0.05    ## s real, per enemy kill
const DEATH_DURATION := 0.18   ## s real, on player death — a bigger beat
const FROZEN_SCALE := 0.02     ## not 0: keep frames/audio ticking so we can thaw
const KILL_COOLDOWN := 0.13    ## s real between kill taps — anti-strobe in a swarm

var _frozen := false
var _thaw_at_us := 0
var _next_tap_at_us := 0


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)


func _process(_delta: float) -> void:
	# _delta is the SCALED clock — useless while frozen. Use the real wall clock.
	if _frozen and Time.get_ticks_usec() >= _thaw_at_us:
		_frozen = false
		Engine.time_scale = 1.0


## Always restore real time if we're torn down mid-freeze (CP 2.1 transitions).
func _exit_tree() -> void:
	if _frozen:
		_frozen = false
		Engine.time_scale = 1.0


func _on_enemy_killed(_at: Vector2) -> void:
	var now := Time.get_ticks_usec()
	if now < _next_tap_at_us:
		return  # still cooling down — swallow this swarm kill's tap
	_next_tap_at_us = now + int(KILL_COOLDOWN * 1_000_000.0)
	_freeze(KILL_DURATION)


func _on_player_died(_player_index: int) -> void:
	_freeze(DEATH_DURATION)


func _freeze(duration: float) -> void:
	var scale: float = SettingsStore.hitstop_intensity
	if scale <= 0.0:
		return
	Engine.time_scale = FROZEN_SCALE
	var thaw := Time.get_ticks_usec() + int(duration * scale * 1_000_000.0)
	_thaw_at_us = maxi(_thaw_at_us, thaw)  # overlapping freezes extend, never cut short
	_frozen = true
