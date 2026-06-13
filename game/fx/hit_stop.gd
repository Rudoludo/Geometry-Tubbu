class_name HitStop
extends Node
## Brief time-freeze that punctuates the biggest beats (CP 1.6). Drops
## Engine.time_scale to near-zero for a few real milliseconds, then restores it.
##
## Player death triggers it. Regular **enemy kills do NOT** — and that's the fix
## for the "stutter on every death": in a swarm shooter you kill constantly, so a
## 50 ms freeze per kill carpeted the whole combat loop in slow-mo. It fired on
## its cooldown (~3 frozen frames, then ~5 normal, repeating at 60 fps), which
## reads as the game lurching/stuttering whenever things die. Kills still get
## their non-freezing juice — screenshake (ArenaCamera) + grid ripple
## (GridBackground) + the death-pop particles — none of which slow time.
##
## When elite/boss kills arrive (CP 3.x) they can opt back in by calling
## [method freeze] directly — selectively, never on every trash mob.
##
## Settings-scaled (SettingsStore.hitstop_intensity): 1.0 = full, 0 = off. The
## freeze runs on REAL time (Time.get_ticks_usec, immune to the scaled clock it
## just set), so it always thaws even though it scaled time itself to a crawl.

const DEATH_DURATION := 0.18   ## s real, on player death — the big beat
const FROZEN_SCALE := 0.02     ## not 0: keep frames/audio ticking so we can thaw

var _frozen := false
var _thaw_at_us := 0


func _ready() -> void:
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


func _on_player_died(_player_index: int) -> void:
	freeze(DEATH_DURATION)


## Freeze real time for `duration` seconds (scaled by the setting). Public so a
## future elite/boss-kill crunch can fire it selectively. Overlapping freezes
## extend, never cut short.
func freeze(duration: float) -> void:
	var scale: float = SettingsStore.hitstop_intensity
	if scale <= 0.0:
		return
	Engine.time_scale = FROZEN_SCALE
	var thaw := Time.get_ticks_usec() + int(duration * scale * 1_000_000.0)
	_thaw_at_us = maxi(_thaw_at_us, thaw)  # overlapping freezes extend, never cut short
	_frozen = true
