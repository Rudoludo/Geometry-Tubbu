class_name ArenaCamera
extends Camera2D
## Arena-clamped follow camera: a subtly smoothed follow with a small velocity
## lead so the view drifts toward where you're heading.
##
## Co-op note (PLAN.md): the camera is owned by the arena/game and accepts N
## players — v1 follows player 0, framing several (centroid + zoom-to-fit) is the
## co-op extension. It is never a child of a player (that would inherit the
## ship's heading/banking and spin the world).

## How far ahead the camera looks, expressed as seconds of travel — decoupled
## from the player's top speed so tuning either stays independent.
const LEAD_TIME := 0.16
const MAX_LEAD := 150.0
## Position smoothing speed; low enough to feel like a follow, not a snap.
const FOLLOW_SMOOTH := 6.0

# --- Screenshake (CP 1.6) ---------------------------------------------------
## Eased magnitude → pixels. Translation-only (no roll): rotation would fight
## `ignore_rotation` and smears bullets more than it's worth in a one-hit game.
## Kept modest so the densest swarm shake never makes bullets unreadable
## (readability rule); the player can scale or kill it via the setting.
const SHAKE_MAX_OFFSET := 22.0   ## px at full (trauma == 1)
const KILL_TRAUMA := 0.08        ## per enemy kill — small, so swarms don't pile up
const DEATH_TRAUMA := 0.8        ## the one-hit death is the big slam

var target: Node2D

var _shake := ScreenShake.new()


func _ready() -> void:
	ignore_rotation = true
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SMOOTH
	# The camera owns the trauma so shake reads against the followed view; the
	# pure ScreenShake holds the curve. Both events feed it (co-op: any death).
	EventBus.enemy_killed.connect(func(_at: Vector2) -> void: _shake.add(KILL_TRAUMA))
	EventBus.player_died.connect(func(_index: int) -> void: _shake.add(DEATH_TRAUMA))


## Pin the view inside the arena so walls never reveal the void beyond them.
func setup_limits(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func _process(delta: float) -> void:
	if target != null:
		var lead := Vector2.ZERO
		if "velocity" in target:
			lead = (target.velocity * LEAD_TIME).limit_length(MAX_LEAD)
		global_position = target.global_position + lead
	_apply_shake(delta)


## Shake rides in the camera's local offset, NOT global_position, so it never
## fights the follow or the arena limit clamp. Random jitter each frame scaled
## by the eased trauma and the player's setting.
func _apply_shake(delta: float) -> void:
	_shake.tick(delta)
	var scaled: float = _shake.shake() * SettingsStore.screenshake_intensity
	if scaled <= 0.0:
		offset = Vector2.ZERO
		return
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* SHAKE_MAX_OFFSET * scaled
