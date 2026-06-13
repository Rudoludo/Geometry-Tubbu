class_name IdleAnimation
extends RefCounted
## Tubbu's idle personality (CP 1.8): a squash/stretch "breathe", a gentle
## world-space "bob", and a periodic eye "blink". Frame-time in, animation state
## out — no nodes, no engine singletons — so the curves are unit-tested. The
## visual application lives in Tubbu, and the amplitudes come from the
## SkinResource (asset rule: each Tubbu variant emotes differently).
##
## Tubbu fades the bob/breathe out as it speeds up (an "idle factor"), so the
## personality never fights the flight feel; the blink runs regardless — it is
## subtle enough to charm at any speed.

## A blink: the eye squashes shut and reopens over this window, once per cycle.
const BLINK_DURATION := 0.14

# Per-skin amplitudes, set by Tubbu from the SkinResource.
var bob_amplitude := 3.0       ## px of world-space hover at full idle
var breathe_amplitude := 0.06  ## squash/stretch as a fraction of size
var cycle_time := 1.6          ## s per bob/breathe cycle
var blink_interval := 3.2      ## s between blinks

var _time := 0.0


## Advance the animation clock. Call once per frame, before the reads.
func tick(delta: float) -> void:
	_time += delta


## Signed world-space vertical hover offset (px).
func bob() -> float:
	if cycle_time <= 0.0:
		return 0.0
	return sin(TAU * _time / cycle_time) * bob_amplitude


## Signed squash/stretch factor `b`: the caller scales the body by
## (1 + b, 1 - b) so it breathes while keeping its rough size.
func breathe() -> float:
	if cycle_time <= 0.0:
		return 0.0
	return sin(TAU * _time / cycle_time) * breathe_amplitude


## Eye openness 0 (shut) .. 1 (open). 1 except during the brief blink at the
## start of each interval, where it dips to 0 and back.
func blink_openness() -> float:
	if blink_interval <= 0.0:
		return 1.0
	var phase := fmod(_time, blink_interval)
	if phase >= BLINK_DURATION:
		return 1.0
	# 1 -> 0 -> 1 across the blink window.
	return 1.0 - sin(PI * phase / BLINK_DURATION)
